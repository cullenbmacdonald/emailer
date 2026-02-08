package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/gorilla/websocket"
)

// dialWS upgrades to a WebSocket on the test server with the given token.
func dialWS(t *testing.T, server *httptest.Server, token string) *websocket.Conn {
	t.Helper()
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/api/v1/ws?token=" + token
	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	if resp != nil {
		_ = resp.Body.Close()
	}
	return conn
}

func TestWebSocket_RejectsInvalidToken(t *testing.T) {
	srv := NewServer(":0", nil, "valid-token", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/api/v1/ws?token=bad-token"
	_, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err == nil {
		t.Fatal("expected error for invalid token")
	}
	if resp != nil {
		_ = resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401, got %d", resp.StatusCode)
		}
	}
}

func TestWebSocket_RejectsMissingToken(t *testing.T) {
	srv := NewServer(":0", nil, "valid-token", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	wsURL := "ws" + strings.TrimPrefix(ts.URL, "http") + "/api/v1/ws"
	_, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err == nil {
		t.Fatal("expected error for missing token")
	}
	if resp != nil {
		_ = resp.Body.Close()
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401, got %d", resp.StatusCode)
		}
	}
}

func TestWebSocket_ConnectsWithValidToken(t *testing.T) {
	srv := NewServer(":0", nil, "valid-token", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "valid-token")
	defer func() { _ = conn.Close() }()

	if srv.hub.ClientCount() != 1 {
		t.Errorf("expected 1 client, got %d", srv.hub.ClientCount())
	}
}

func TestWebSocket_BroadcastReachesClient(t *testing.T) {
	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "tok")
	defer func() { _ = conn.Close() }()

	evt, err := models.NewWebSocketEvent(models.WSEventEmailDeleted, map[string]string{"email_id": "abc"})
	if err != nil {
		t.Fatal(err)
	}
	srv.hub.Broadcast(evt)

	if err := conn.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}

	var received models.WebSocketEvent
	if err := json.Unmarshal(msg, &received); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if received.Type != models.WSEventEmailDeleted {
		t.Errorf("expected type %q, got %q", models.WSEventEmailDeleted, received.Type)
	}
	if received.Timestamp.IsZero() {
		t.Error("expected non-zero timestamp")
	}
}

func TestWebSocket_BroadcastEvent(t *testing.T) {
	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "tok")
	defer func() { _ = conn.Close() }()

	srv.hub.BroadcastEvent(models.WSEventAccountStatus, map[string]string{
		"account_id": "123",
		"status":     "online",
	})

	if err := conn.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}

	var received models.WebSocketEvent
	if err := json.Unmarshal(msg, &received); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if received.Type != models.WSEventAccountStatus {
		t.Errorf("expected type %q, got %q", models.WSEventAccountStatus, received.Type)
	}
}

func TestWebSocket_PingPong(t *testing.T) {
	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "tok")
	defer func() { _ = conn.Close() }()

	ping := models.WebSocketEvent{Type: models.WSEventPing, Timestamp: time.Now().UTC()}
	if err := conn.WriteJSON(ping); err != nil {
		t.Fatalf("write ping: %v", err)
	}

	if err := conn.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatal(err)
	}
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read pong: %v", err)
	}

	var pong models.WebSocketEvent
	if err := json.Unmarshal(msg, &pong); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if pong.Type != models.WSEventPong {
		t.Errorf("expected pong, got %q", pong.Type)
	}
}

func TestWebSocket_MultipleClients(t *testing.T) {
	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	const numClients = 5
	conns := make([]*websocket.Conn, numClients)
	for i := range conns {
		conns[i] = dialWS(t, ts, "tok")
		defer func(c *websocket.Conn) { _ = c.Close() }(conns[i])
	}

	time.Sleep(50 * time.Millisecond)
	if got := srv.hub.ClientCount(); got != numClients {
		t.Fatalf("expected %d clients, got %d", numClients, got)
	}

	srv.hub.BroadcastEvent(models.WSEventDigestAvailable, map[string]string{"digest_id": "d1"})

	var wg sync.WaitGroup
	for i, conn := range conns {
		wg.Add(1)
		go func(idx int, c *websocket.Conn) {
			defer wg.Done()
			if err := c.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
				t.Errorf("client %d set deadline: %v", idx, err)
				return
			}
			_, msg, err := c.ReadMessage()
			if err != nil {
				t.Errorf("client %d read: %v", idx, err)
				return
			}
			var evt models.WebSocketEvent
			if err := json.Unmarshal(msg, &evt); err != nil {
				t.Errorf("client %d unmarshal: %v", idx, err)
				return
			}
			if evt.Type != models.WSEventDigestAvailable {
				t.Errorf("client %d: expected %q, got %q", idx, models.WSEventDigestAvailable, evt.Type)
			}
		}(i, conn)
	}
	wg.Wait()
}

func TestWebSocket_GracefulDisconnect(t *testing.T) {
	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "tok")

	if err := conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, "")); err != nil {
		t.Logf("write close: %v", err)
	}
	_ = conn.Close()

	time.Sleep(100 * time.Millisecond)
	if got := srv.hub.ClientCount(); got != 0 {
		t.Errorf("expected 0 clients after disconnect, got %d", got)
	}
}

func TestHub_BroadcastToEmptyHub(t *testing.T) {
	h := NewHub()
	evt, _ := models.NewWebSocketEvent(models.WSEventEmailNew, nil)
	h.Broadcast(evt)
}

func TestWebSocket_AllEventTypes(t *testing.T) {
	types := []string{
		models.WSEventEmailNew,
		models.WSEventEmailUpdated,
		models.WSEventEmailDeleted,
		models.WSEventClassificationChanged,
		models.WSEventSnoozeCreated,
		models.WSEventSnoozeReturned,
		models.WSEventSnoozeCancelled,
		models.WSEventRecommendationNew,
		models.WSEventRecommendationUpdated,
		models.WSEventDigestAvailable,
		models.WSEventAccountStatus,
	}

	srv := NewServer(":0", nil, "tok", nil, BuildInfo{})
	ts := httptest.NewServer(srv.httpServer.Handler)
	defer ts.Close()

	conn := dialWS(t, ts, "tok")
	defer func() { _ = conn.Close() }()

	for _, evtType := range types {
		srv.hub.BroadcastEvent(evtType, map[string]string{"test": "data"})

		if err := conn.SetReadDeadline(time.Now().Add(2 * time.Second)); err != nil {
			t.Fatal(err)
		}
		_, msg, err := conn.ReadMessage()
		if err != nil {
			t.Fatalf("read %s: %v", evtType, err)
		}

		var received models.WebSocketEvent
		if err := json.Unmarshal(msg, &received); err != nil {
			t.Fatalf("unmarshal %s: %v", evtType, err)
		}
		if received.Type != evtType {
			t.Errorf("expected type %q, got %q", evtType, received.Type)
		}
	}
}
