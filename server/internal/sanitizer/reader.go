package sanitizer

import (
	"regexp"
	"strings"
)

// Patterns for newsletter chrome to strip in reader mode.
var (
	// Unsubscribe keywords to detect in blocks
	unsubscribeKeywords = []string{
		"unsubscribe",
		"opt-out",
		"opt out",
		"manage your preferences",
		"manage preferences",
		"manage your subscription",
		"email preferences",
		"update your preferences",
	}

	// "View in browser" keywords
	viewInBrowserKeywords = []string{
		"view in browser",
		"view in your browser",
		"view online",
		"view as a web page",
		"can't see this",
		"trouble viewing this",
		"trouble reading this",
	}

	// Social media share keywords
	socialShareKeywords = []string{
		"facebook.com/share",
		"twitter.com/intent",
		"linkedin.com/share",
		"pinterest.com/pin",
	}

	// Redundant logo pattern
	logoPatternRe = regexp.MustCompile(`(?i)(?:logo|banner|header[_-]img|masthead)`)

	// Block tag pattern for extracting blocks
	blockRe = regexp.MustCompile(`(?is)<(div|p|td|tr|section)\b[^>]*>.*?</(?:div|p|td|tr|section)>`)
)

// ReaderMode strips newsletter chrome from sanitized HTML, leaving article content.
func ReaderMode(html string) string {
	if html == "" {
		return html
	}

	// First apply standard sanitization
	html = Sanitize(html)

	// Remove blocks containing "view in browser" keywords
	html = removeBlocksWithKeywords(html, viewInBrowserKeywords)

	// Remove blocks containing unsubscribe keywords
	html = removeBlocksWithKeywords(html, unsubscribeKeywords)

	// Remove social share button blocks
	html = removeBlocksWithKeywords(html, socialShareKeywords)

	// Remove redundant logo images (keep the first, remove subsequent)
	html = removeRedundantLogos(html)

	return html
}

// removeBlocksWithKeywords finds the smallest block-level elements containing
// any of the given keywords and removes them.
func removeBlocksWithKeywords(html string, keywords []string) string {
	matches := blockRe.FindAllStringIndex(html, -1)
	if len(matches) == 0 {
		return html
	}

	// Process in reverse so indices stay valid
	for i := len(matches) - 1; i >= 0; i-- {
		block := strings.ToLower(html[matches[i][0]:matches[i][1]])
		for _, kw := range keywords {
			if strings.Contains(block, kw) {
				html = html[:matches[i][0]] + html[matches[i][1]:]
				break
			}
		}
	}

	return html
}

// removeRedundantLogos finds img tags that match logo patterns and removes all
// but the first occurrence.
func removeRedundantLogos(html string) string {
	imgRe := regexp.MustCompile(`(?i)<img[^>]*/?>`)
	matches := imgRe.FindAllStringIndex(html, -1)
	if len(matches) < 2 {
		return html
	}

	// Find which matches are logos
	var logoIndices []int
	for i, m := range matches {
		imgTag := html[m[0]:m[1]]
		if logoPatternRe.MatchString(imgTag) {
			logoIndices = append(logoIndices, i)
		}
	}

	if len(logoIndices) < 2 {
		return html
	}

	// Remove all but the first logo, processing in reverse order
	for j := len(logoIndices) - 1; j >= 1; j-- {
		idx := logoIndices[j]
		html = html[:matches[idx][0]] + html[matches[idx][1]:]
	}

	return html
}
