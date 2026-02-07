package models

import "time"

// SnoozeState represents the current snooze state of an email.
type SnoozeState struct {
	ID          string    `json:"id"`
	EmailID     string    `json:"email_id"`
	SnoozedAt   time.Time `json:"snoozed_at"`
	ReturnAt    time.Time `json:"return_at"`
	SnoozeCount int       `json:"snooze_count"`
	IsActive    bool      `json:"is_active"`
}

// SnoozeRequest is the request body for snoozing an email.
type SnoozeRequest struct {
	ReturnAt time.Time `json:"return_at"`
}
