// Package sanitizer provides HTML sanitization for email bodies.
// It strips scripts, tracking pixels, and dangerous elements while
// preserving content structure.
package sanitizer

import (
	"regexp"
	"strings"
)

// Known tracking pixel domains.
var trackingDomains = map[string]bool{
	"open.convertkit.com":           true,
	"track.mailchimp.com":           true,
	"pixel.monitor1.returnpath.net": true,
	"list-manage.com":               true,
	"t.emailtracking.com":           true,
	"beacon.krxd.net":               true,
	"ci4.googleusercontent.com":     true,
	"www.google-analytics.com":      true,
	"trk.klclick.com":               true,
	"click.pstmrk.it":               true,
	"mandrillapp.com":               true,
	"sendgrid.net":                  true,
}

// Patterns for elements to remove entirely.
var (
	scriptTagRe        = regexp.MustCompile(`(?is)<script[^>]*>.*?</script>`)
	noscriptTagRe      = regexp.MustCompile(`(?is)<noscript[^>]*>.*?</noscript>`)
	styleImportRe      = regexp.MustCompile(`(?is)<style[^>]*>(?:[^<]*@import[^<]*)</style>`)
	eventHandlerRe     = regexp.MustCompile(`(?i)\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]*)`)
	trackingPixelRe    = regexp.MustCompile(`(?i)<img[^>]+(?:width\s*=\s*["']?1["']?\s+height\s*=\s*["']?1["']?|height\s*=\s*["']?1["']?\s+width\s*=\s*["']?1["']?)[^>]*/?>`)
	trackingPixelAltRe = regexp.MustCompile(`(?i)<img[^>]+(?:style\s*=\s*["'][^"']*(?:display\s*:\s*none|width\s*:\s*0|height\s*:\s*0)[^"']*["'])[^>]*/?>`)
	trackingDomainRe   *regexp.Regexp
)

func init() {
	// Build tracking domain pattern
	domains := make([]string, 0, len(trackingDomains))
	for d := range trackingDomains {
		domains = append(domains, regexp.QuoteMeta(d))
	}
	if len(domains) > 0 {
		pattern := `(?i)<img[^>]+src\s*=\s*["']https?://(?:` + strings.Join(domains, "|") + `)[^"']*["'][^>]*/?>` //nolint:gocritic // false positive
		trackingDomainRe = regexp.MustCompile(pattern)
	}
}

// Sanitize removes dangerous elements from HTML email bodies.
// It strips scripts, tracking pixels, event handlers, and style imports.
func Sanitize(html string) string {
	if html == "" {
		return html
	}

	// Remove script tags
	html = scriptTagRe.ReplaceAllString(html, "")

	// Remove noscript tags
	html = noscriptTagRe.ReplaceAllString(html, "")

	// Remove style tags with @import (external resource loading)
	html = styleImportRe.ReplaceAllString(html, "")

	// Remove inline event handlers (onclick, onload, etc.)
	html = eventHandlerRe.ReplaceAllString(html, "")

	// Remove 1x1 tracking pixels
	html = trackingPixelRe.ReplaceAllString(html, "")

	// Remove hidden tracking images
	html = trackingPixelAltRe.ReplaceAllString(html, "")

	// Remove images from known tracking domains
	if trackingDomainRe != nil {
		html = trackingDomainRe.ReplaceAllString(html, "")
	}

	return html
}
