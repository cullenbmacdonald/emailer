package models

import "time"

// ComposeRequest is the request body for sending an email.
type ComposeRequest struct {
	AccountID string   `json:"account_id"`
	To        []string `json:"to"`
	CC        []string `json:"cc,omitempty"`
	BCC       []string `json:"bcc,omitempty"`
	Subject   string   `json:"subject"`
	Body      string   `json:"body"`
	HTMLBody  string   `json:"html_body,omitempty"`
	InReplyTo string   `json:"in_reply_to,omitempty"`
	ForwardOf string   `json:"forward_of,omitempty"`
}

// ComposeSendResponse is returned after successfully sending an email.
type ComposeSendResponse struct {
	MessageID string `json:"message_id"`
}

// Draft represents a saved email draft.
type Draft struct {
	ID        string    `json:"id"`
	AccountID string    `json:"account_id"`
	To        []string  `json:"to,omitempty"`
	CC        []string  `json:"cc,omitempty"`
	BCC       []string  `json:"bcc,omitempty"`
	Subject   string    `json:"subject,omitempty"`
	Body      string    `json:"body,omitempty"`
	HTMLBody  string    `json:"html_body,omitempty"`
	InReplyTo string    `json:"in_reply_to,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// DraftListResponse is the paginated response for draft listings.
type DraftListResponse struct {
	Data       []Draft `json:"data"`
	NextCursor string  `json:"next_cursor,omitempty"`
	HasMore    bool    `json:"has_more"`
}
