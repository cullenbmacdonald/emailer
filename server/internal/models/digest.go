package models

import "time"

// Digest type values.
const (
	DigestTypeMorning = "morning"
	DigestTypeEvening = "evening"
)

// DailyDigest is the full digest with sections.
type DailyDigest struct {
	ID          string          `json:"id"`
	DigestType  string          `json:"digest_type"`
	GeneratedAt time.Time       `json:"generated_at"`
	IsRead      bool            `json:"is_read"`
	Sections    []DigestSection `json:"sections"`
}

// DigestSection is a single section within a digest.
type DigestSection struct {
	Type             string         `json:"type"`
	Title            string         `json:"title"`
	Subtitle         string         `json:"subtitle,omitempty"`
	Count            *int           `json:"count,omitempty"`
	AccountBreakdown []AccountCount `json:"account_breakdown,omitempty"`
	Items            []DigestItem   `json:"items,omitempty"`
	SentCount        *int           `json:"sent_count,omitempty"`
	ArchivedCount    *int           `json:"archived_count,omitempty"`
}

// DigestItem is an actionable item within a digest section.
type DigestItem struct {
	Type                 string     `json:"type"`
	EmailID              string     `json:"email_id"`
	Subject              string     `json:"subject,omitempty"`
	From                 string     `json:"from,omitempty"`
	ReturnAt             *time.Time `json:"return_at,omitempty"`
	SnoozeCount          *int       `json:"snooze_count,omitempty"`
	Confidence           *float64   `json:"confidence,omitempty"`
	Explanation          string     `json:"explanation,omitempty"`
	HighlightType        string     `json:"highlight_type,omitempty"`
	DisplayText          string     `json:"display_text,omitempty"`
	NewsletterName       string     `json:"newsletter_name,omitempty"`
	DaysSinceFirstSnooze *int       `json:"days_since_first_snooze,omitempty"`
}

// AccountCount holds per-account counts for digest summaries.
type AccountCount struct {
	AccountID    string `json:"account_id"`
	AccountName  string `json:"account_name"`
	AccountColor string `json:"account_color"`
	Count        int    `json:"count"`
}

// DigestSummary is the list-item representation of a digest.
type DigestSummary struct {
	ID          string    `json:"id"`
	DigestType  string    `json:"digest_type"`
	GeneratedAt time.Time `json:"generated_at"`
	IsRead      bool      `json:"is_read"`
}

// DigestUpdateRequest is a partial update for digest metadata.
type DigestUpdateRequest struct {
	IsRead *bool `json:"is_read,omitempty"`
}

// DigestListResponse is the paginated response for digest listings.
type DigestListResponse struct {
	Data       []DigestSummary `json:"data"`
	NextCursor string          `json:"next_cursor,omitempty"`
	HasMore    bool            `json:"has_more"`
}
