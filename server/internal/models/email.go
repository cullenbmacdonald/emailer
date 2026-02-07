// Package models defines data types mirroring the API spec schemas.
// All types are dependency-free (standard library only) and use
// snake_case JSON tags matching the API specification.
package models

import "time"

// Contact represents an email sender or recipient.
type Contact struct {
	Name  string `json:"name,omitempty"`
	Email string `json:"email"`
}

// Email is the list-item representation (no body).
type Email struct {
	ID                  string          `json:"id"`
	AccountID           string          `json:"account_id"`
	MessageID           string          `json:"message_id,omitempty"`
	ThreadID            string          `json:"thread_id,omitempty"`
	From                Contact         `json:"from"`
	To                  []Contact       `json:"to"`
	CC                  []Contact       `json:"cc,omitempty"`
	Subject             string          `json:"subject"`
	Snippet             string          `json:"snippet"`
	ReceivedAt          time.Time       `json:"received_at"`
	Classification      *Classification `json:"classification"`
	IsRead              bool            `json:"is_read"`
	IsArchived          bool            `json:"is_archived"`
	HasAttachments      bool            `json:"has_attachments"`
	Snooze              *SnoozeState    `json:"snooze,omitempty"`
	Labels              []string        `json:"labels,omitempty"`
	AccountColor        string          `json:"account_color,omitempty"`
	AccountName         string          `json:"account_name,omitempty"`
	RecommendationCount *int            `json:"recommendation_count,omitempty"`
	LastReadAt          *time.Time      `json:"last_read_at,omitempty"`
	ReadProgress        *float64        `json:"read_progress,omitempty"`
	DaysUntilExpiry     *int            `json:"days_until_expiry,omitempty"`
}

// EmailDetail is the full email with body content.
type EmailDetail struct {
	ID          string       `json:"id"`
	Email       Email        `json:"email"`
	HTMLBody    string       `json:"html_body"`
	TextBody    string       `json:"text_body,omitempty"`
	Attachments []Attachment `json:"attachments"`
}

// Attachment represents a file attached to an email.
type Attachment struct {
	ID          string `json:"id"`
	Filename    string `json:"filename"`
	MIMEType    string `json:"mime_type"`
	Size        int    `json:"size"`
	DownloadURL string `json:"download_url,omitempty"`
}

// EmailUpdateRequest is a partial update for email metadata.
type EmailUpdateRequest struct {
	IsRead       *bool    `json:"is_read,omitempty"`
	IsArchived   *bool    `json:"is_archived,omitempty"`
	ReadProgress *float64 `json:"read_progress,omitempty"`
}

// EmailListResponse is the paginated response for email listings.
type EmailListResponse struct {
	Data       []Email `json:"data"`
	NextCursor string  `json:"next_cursor,omitempty"`
	HasMore    bool    `json:"has_more"`
}
