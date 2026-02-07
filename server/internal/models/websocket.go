package models

import "encoding/json"

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
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}
