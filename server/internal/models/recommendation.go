package models

import "time"

// Recommendation type values.
const (
	RecTypeBook    = "book"
	RecTypeMovie   = "movie"
	RecTypeTV      = "tv"
	RecTypeMusic   = "music"
	RecTypeArticle = "article"
	RecTypePodcast = "podcast"
	RecTypeOther   = "other"
)

// Recommendation status values.
const (
	RecStatusNew       = "new"
	RecStatusSaved     = "saved"
	RecStatusDone      = "done"
	RecStatusDismissed = "dismissed"
)

// Recommendation is the list-item representation.
type Recommendation struct {
	ID                   string    `json:"id"`
	Type                 string    `json:"type"`
	Title                string    `json:"title"`
	Creator              string    `json:"creator,omitempty"`
	SourceNewsletterName string    `json:"source_newsletter_name"`
	SourceEmailID        string    `json:"source_email_id,omitempty"`
	SourceDate           time.Time `json:"source_date"`
	ContextSnippet       string    `json:"context_snippet"`
	Status               string    `json:"status"`
	DuplicateCount       int       `json:"duplicate_count"`
	IsUserAdded          bool      `json:"is_user_added"`
	CreatedAt            time.Time `json:"created_at"`
}

// RecommendationDetail includes full context and duplicate sources.
type RecommendationDetail struct {
	Recommendation   Recommendation    `json:"recommendation"`
	FullContext      string            `json:"full_context,omitempty"`
	DuplicateSources []DuplicateSource `json:"duplicate_sources"`
}

// DuplicateSource tracks where a recommendation was mentioned.
type DuplicateSource struct {
	NewsletterName string    `json:"newsletter_name"`
	EmailID        string    `json:"email_id,omitempty"`
	Date           time.Time `json:"date"`
	ContextSnippet string    `json:"context_snippet"`
}

// RecommendationCreateRequest is the request body for user-added recommendations.
type RecommendationCreateRequest struct {
	Type           string `json:"type"`
	Title          string `json:"title"`
	Creator        string `json:"creator,omitempty"`
	ContextSnippet string `json:"context_snippet,omitempty"`
}

// RecommendationUpdateRequest is the request body for status changes.
type RecommendationUpdateRequest struct {
	Status string `json:"status"`
}

// RecommendationListResponse is the paginated response for recommendation listings.
type RecommendationListResponse struct {
	Data       []Recommendation `json:"data"`
	NextCursor string           `json:"next_cursor,omitempty"`
	HasMore    bool             `json:"has_more"`
}

// ValidRecommendationTypes returns all valid recommendation type values.
func ValidRecommendationTypes() []string {
	return []string{RecTypeBook, RecTypeMovie, RecTypeTV, RecTypeMusic, RecTypeArticle, RecTypePodcast, RecTypeOther}
}

// ValidRecommendationStatuses returns all valid recommendation status values.
func ValidRecommendationStatuses() []string {
	return []string{RecStatusNew, RecStatusSaved, RecStatusDone, RecStatusDismissed}
}
