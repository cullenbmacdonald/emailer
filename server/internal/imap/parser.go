package imap

import (
	"errors"
	"fmt"
	"io"
	"strings"
	"unicode"

	"github.com/emersion/go-message"
	"github.com/emersion/go-message/mail"
)

// ParsedEmail holds the extracted content from a MIME email message.
type ParsedEmail struct {
	HTMLBody    string
	TextBody    string
	Snippet     string
	Attachments []ParsedAttachment
}

// ParsedAttachment holds metadata about an email attachment (not the content).
type ParsedAttachment struct {
	Filename string
	MIMEType string
	Size     int
}

// maxSnippetLen is the target length for the text snippet.
const maxSnippetLen = 200

// ParseMIME reads an RFC 5322 message from r and extracts bodies and attachment metadata.
// It handles multipart/alternative (prefers HTML, falls back to text),
// multipart/mixed (body + attachments), and charset encoding.
// Malformed parts are logged as warnings but do not fail the whole parse.
func ParseMIME(r io.Reader) (*ParsedEmail, error) {
	mr, err := mail.CreateReader(r)
	if err != nil && !message.IsUnknownCharset(err) {
		return nil, fmt.Errorf("create mail reader: %w", err)
	}

	result := &ParsedEmail{}

	for {
		part, err := mr.NextPart()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil && !message.IsUnknownCharset(err) {
			// Malformed part — skip but don't fail the whole message.
			continue
		}

		switch h := part.Header.(type) {
		case *mail.InlineHeader:
			ct, _, _ := h.ContentType()
			body, readErr := io.ReadAll(part.Body)
			if readErr != nil {
				continue
			}
			content := string(body)

			switch {
			case strings.HasPrefix(ct, "text/html"):
				if result.HTMLBody == "" {
					result.HTMLBody = content
				}
			case strings.HasPrefix(ct, "text/plain"):
				if result.TextBody == "" {
					result.TextBody = content
				}
			}

		case *mail.AttachmentHeader:
			filename, _ := h.Filename()
			ct, _, _ := h.ContentType()

			// Read body to determine size, then discard content.
			body, readErr := io.ReadAll(part.Body)
			size := 0
			if readErr == nil {
				size = len(body)
			}

			result.Attachments = append(result.Attachments, ParsedAttachment{
				Filename: filename,
				MIMEType: ct,
				Size:     size,
			})
		}
	}

	result.Snippet = generateSnippet(result.TextBody, result.HTMLBody)

	return result, nil
}

// generateSnippet creates a ~200-character snippet from the text body,
// falling back to stripping HTML if no text body is available.
func generateSnippet(textBody, htmlBody string) string {
	source := textBody
	if source == "" {
		source = stripHTMLBasic(htmlBody)
	}
	if source == "" {
		return ""
	}

	// Normalize whitespace: collapse runs of whitespace into single spaces.
	normalized := normalizeWhitespace(source)
	normalized = strings.TrimSpace(normalized)

	if len(normalized) <= maxSnippetLen {
		return normalized
	}

	// Truncate at word boundary.
	truncated := normalized[:maxSnippetLen]
	if idx := strings.LastIndexByte(truncated, ' '); idx > maxSnippetLen/2 {
		truncated = truncated[:idx]
	}
	return truncated + "..."
}

// normalizeWhitespace collapses consecutive whitespace characters into a single space.
func normalizeWhitespace(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	inSpace := false
	for _, r := range s {
		if unicode.IsSpace(r) {
			if !inSpace {
				b.WriteByte(' ')
				inSpace = true
			}
		} else {
			b.WriteRune(r)
			inSpace = false
		}
	}
	return b.String()
}

// stripHTMLBasic removes HTML tags for snippet generation.
// This is a basic implementation — not a full HTML parser.
func stripHTMLBasic(html string) string {
	if html == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(html))
	inTag := false
	for _, r := range html {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
			b.WriteByte(' ') // Replace tag boundaries with space.
		case !inTag:
			b.WriteRune(r)
		}
	}
	return b.String()
}
