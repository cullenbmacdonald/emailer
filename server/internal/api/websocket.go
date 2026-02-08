package api

import (
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
)

const (
	// writeWait is the time allowed to write a message to the peer.
	writeWait = 10 * time.Second

	// pongWait is the time allowed to read the next pong message from the peer.
	pongWait = 60 * time.Second

	// pingInterval is the interval at which the server sends pings to the peer.
	// Must be less than pongWait.
	pingInterval = 54 * time.Second

	// maxMessageSize is the maximum message size allowed from the peer.
	maxMessageSize = 512
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(_ *http.Request) bool {
		// Allow all origins; auth is via token query param.
		return true
	},
}

// Hub manages WebSocket client connections and broadcasts events.
type Hub struct {
	mu      sync.RWMutex
	clients map[*wsClient]struct{}
}

// NewHub creates a new WebSocket hub.
func NewHub() *Hub {
	return &Hub{
		clients: make(map[*wsClient]struct{}),
	}
}

// Broadcast sends an event to all connected clients.
func (h *Hub) Broadcast(event models.WebSocketEvent) {
	data, err := json.Marshal(event)
	if err != nil {
		log.Error().Err(err).Str("event_type", event.Type).Msg("failed to marshal websocket event")
		return
	}

	h.mu.RLock()
	clients := make([]*wsClient, 0, len(h.clients))
	for c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	for _, c := range clients {
		select {
		case c.send <- data:
		default:
			// Client send buffer full; disconnect it.
			h.removeClient(c)
		}
	}
}

// BroadcastEvent is a convenience that builds a WebSocketEvent and broadcasts it.
func (h *Hub) BroadcastEvent(eventType string, payload any) {
	evt, err := models.NewWebSocketEvent(eventType, payload)
	if err != nil {
		log.Error().Err(err).Str("event_type", eventType).Msg("failed to create websocket event")
		return
	}
	h.Broadcast(evt)
}

// ClientCount returns the number of connected clients.
func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

func (h *Hub) addClient(c *wsClient) {
	h.mu.Lock()
	h.clients[c] = struct{}{}
	h.mu.Unlock()
	log.Debug().Int("clients", h.ClientCount()).Msg("websocket client connected")
}

func (h *Hub) removeClient(c *wsClient) {
	h.mu.Lock()
	if _, ok := h.clients[c]; ok {
		delete(h.clients, c)
		close(c.send)
	}
	h.mu.Unlock()
	log.Debug().Int("clients", h.ClientCount()).Msg("websocket client disconnected")
}

// wsClient represents a single WebSocket connection.
type wsClient struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte
}

// readPump reads messages from the WebSocket connection.
// It handles ping messages from the client and responds with pong.
func (c *wsClient) readPump() {
	defer func() {
		c.hub.removeClient(c)
		_ = c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	if err := c.conn.SetReadDeadline(time.Now().Add(pongWait)); err != nil {
		return
	}
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Warn().Err(err).Msg("websocket unexpected close")
			}
			return
		}

		// Handle client ping messages (application-level, per API spec).
		var evt models.WebSocketEvent
		if json.Unmarshal(message, &evt) == nil && evt.Type == models.WSEventPing {
			pong, marshalErr := json.Marshal(models.WebSocketEvent{
				Type:      models.WSEventPong,
				Timestamp: time.Now().UTC(),
			})
			if marshalErr == nil {
				select {
				case c.send <- pong:
				default:
				}
			}
		}
	}
}

// writePump writes messages from the send channel to the WebSocket connection.
// It also sends periodic WebSocket-level pings to detect dead connections.
func (c *wsClient) writePump() {
	ticker := time.NewTicker(pingInterval)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			if err := c.conn.SetWriteDeadline(time.Now().Add(writeWait)); err != nil {
				return
			}
			if !ok {
				// Hub closed the channel.
				_ = c.conn.WriteMessage(websocket.CloseMessage, nil)
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			if err := c.conn.SetWriteDeadline(time.Now().Add(writeWait)); err != nil {
				return
			}
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// handleWebSocket upgrades the HTTP connection to WebSocket and registers the client.
// Authentication is via the "token" query parameter.
func (s *Server) handleWebSocket(authToken string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := r.URL.Query().Get("token")
		if token == "" || token != authToken {
			WriteError(w, http.StatusUnauthorized, "unauthorized", "invalid or missing token")
			return
		}

		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Error().Err(err).Msg("websocket upgrade failed")
			return
		}

		client := &wsClient{
			hub:  s.hub,
			conn: conn,
			send: make(chan []byte, 256),
		}

		s.hub.addClient(client)

		go client.writePump()
		go client.readPump()
	}
}
