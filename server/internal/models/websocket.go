package models

import (
	"encoding/json"
	"time"
)

// WebSocket event type constants (server to client).
const (
	WSEventEmailNew              = "email.new"
	WSEventEmailUpdated          = "email.updated"
	WSEventEmailDeleted          = "email.deleted"
	WSEventClassificationChanged = "classification.changed"
	WSEventSnoozeCreated         = "snooze.created"
	WSEventSnoozeReturned        = "snooze.returned"
	WSEventSnoozeCancelled       = "snooze.cancelled"
	WSEventRecommendationNew     = "recommendation.new"
	WSEventRecommendationUpdated = "recommendation.updated"
	WSEventDigestAvailable       = "digest.available"
	WSEventAccountStatus         = "account.status"
)

// WebSocket event type constants (client to server).
const (
	WSEventPing = "ping"
	WSEventPong = "pong"
)

// WebSocketEvent is the envelope for all WebSocket messages.
type WebSocketEvent struct {
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload,omitempty"`
	Timestamp time.Time       `json:"timestamp"`
}

// NewWebSocketEvent creates a WebSocketEvent with the current timestamp.
// The payload is JSON-marshaled from v. If v is nil, payload is omitted.
func NewWebSocketEvent(eventType string, v any) (WebSocketEvent, error) {
	evt := WebSocketEvent{
		Type:      eventType,
		Timestamp: time.Now().UTC(),
	}
	if v != nil {
		data, err := json.Marshal(v)
		if err != nil {
			return WebSocketEvent{}, err
		}
		evt.Payload = data
	}
	return evt, nil
}
