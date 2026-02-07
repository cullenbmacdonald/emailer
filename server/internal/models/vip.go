package models

import "time"

// VIPSender represents a VIP sender entry.
type VIPSender struct {
	ID      string    `json:"id"`
	Email   string    `json:"email"`
	Name    string    `json:"name,omitempty"`
	AddedAt time.Time `json:"added_at"`
}

// VIPCreateRequest is the request body for adding a VIP sender.
type VIPCreateRequest struct {
	Email string `json:"email"`
	Name  string `json:"name,omitempty"`
}

// VIPListResponse wraps the VIP sender list.
type VIPListResponse struct {
	Data []VIPSender `json:"data"`
}
