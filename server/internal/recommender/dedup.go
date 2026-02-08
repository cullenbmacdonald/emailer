// Package recommender provides LLM-based recommendation extraction from
// newsletter emails with fuzzy deduplication.
package recommender

import (
	"strings"
	"unicode"
)

// NormalizeTitle returns a normalized version of a title for fuzzy matching.
// It lowercases, trims whitespace, collapses internal whitespace, and strips
// leading articles ("the", "a", "an").
func NormalizeTitle(title string) string {
	title = strings.ToLower(strings.TrimSpace(title))
	// Collapse whitespace.
	var b strings.Builder
	prevSpace := false
	for _, r := range title {
		if unicode.IsSpace(r) {
			if !prevSpace {
				b.WriteRune(' ')
			}
			prevSpace = true
		} else {
			b.WriteRune(r)
			prevSpace = false
		}
	}
	title = b.String()

	// Strip common leading articles.
	for _, article := range []string{"the ", "a ", "an "} {
		if strings.HasPrefix(title, article) {
			title = title[len(article):]
			break
		}
	}

	return strings.TrimSpace(title)
}

// TitlesMatch returns true if two titles are considered duplicates after normalization.
func TitlesMatch(a, b string) bool {
	return NormalizeTitle(a) == NormalizeTitle(b)
}
