package models

import "time"

// Account type values.
const (
	AccountTypeWork     = "work"
	AccountTypePersonal = "personal"
)

// Account status values.
const (
	AccountStatusOnline  = "online"
	AccountStatusOffline = "offline"
	AccountStatusError   = "error"
	AccountStatusSyncing = "syncing"
)

// Account represents an email account.
type Account struct {
	ID            string         `json:"id"`
	Name          string         `json:"name"`
	EmailAddress  string         `json:"email_address"`
	AccountType   string         `json:"account_type"`
	Color         string         `json:"color"`
	Status        string         `json:"status"`
	StatusMessage string         `json:"status_message,omitempty"`
	Counts        *AccountCounts `json:"counts,omitempty"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
}

// AccountCounts holds per-view email counts for an account.
type AccountCounts struct {
	ActionQueue        int `json:"action_queue"`
	ReadingQueue       int `json:"reading_queue"`
	Filtered           int `json:"filtered"`
	FilteredBorderline int `json:"filtered_borderline"`
	AllInboxes         int `json:"all_inboxes"`
}

// AccountListResponse wraps the account list.
type AccountListResponse struct {
	Data []Account `json:"data"`
}
