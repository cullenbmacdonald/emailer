package models

// SearchResult wraps an email with a highlighted snippet.
type SearchResult struct {
	Email            Email  `json:"email"`
	HighlightSnippet string `json:"highlight_snippet"`
}

// SearchResponse is the paginated response for search results.
type SearchResponse struct {
	Data       []SearchResult `json:"data"`
	NextCursor string         `json:"next_cursor,omitempty"`
	HasMore    bool           `json:"has_more"`
	Query      string         `json:"query"`
}
