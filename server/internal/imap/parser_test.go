package imap

import (
	"os"
	"strings"
	"testing"
)

func loadTestEmail(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile("../testdata/emails/" + name)
	if err != nil {
		t.Fatalf("failed to load test email %s: %v", name, err)
	}
	return data
}

func TestParseMIME_SimpleText(t *testing.T) {
	data := loadTestEmail(t, "simple_text.eml")
	result, err := ParseMIME(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.HTMLBody != "" {
		t.Errorf("expected no HTML body, got %d bytes", len(result.HTMLBody))
	}
	if !strings.Contains(result.TextBody, "simple plain text email") {
		t.Errorf("expected text body to contain 'simple plain text email', got: %s", result.TextBody)
	}
	if result.Snippet == "" {
		t.Error("expected non-empty snippet")
	}
	if len(result.Attachments) != 0 {
		t.Errorf("expected no attachments, got %d", len(result.Attachments))
	}
}

func TestParseMIME_MultipartAlternative(t *testing.T) {
	data := loadTestEmail(t, "multipart_alternative.eml")
	result, err := ParseMIME(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.HTMLBody == "" {
		t.Error("expected HTML body from multipart/alternative")
	}
	if !strings.Contains(result.HTMLBody, "<strong>HTML version</strong>") {
		t.Error("expected HTML body to contain formatted content")
	}
	if result.TextBody == "" {
		t.Error("expected text body from multipart/alternative")
	}
	if !strings.Contains(result.TextBody, "plain text version") {
		t.Error("expected text body to contain plain text content")
	}
	if len(result.Attachments) != 0 {
		t.Errorf("expected no attachments, got %d", len(result.Attachments))
	}
}

func TestParseMIME_MultipartMixed(t *testing.T) {
	data := loadTestEmail(t, "multipart_mixed.eml")
	result, err := ParseMIME(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.HTMLBody == "" {
		t.Error("expected HTML body from inner multipart/alternative")
	}
	if result.TextBody == "" {
		t.Error("expected text body from inner multipart/alternative")
	}

	if len(result.Attachments) != 2 {
		t.Fatalf("expected 2 attachments, got %d", len(result.Attachments))
	}

	// Check first attachment.
	if result.Attachments[0].Filename != "invoice-2024-001.pdf" {
		t.Errorf("expected filename invoice-2024-001.pdf, got %s", result.Attachments[0].Filename)
	}
	if result.Attachments[0].MIMEType != "application/pdf" {
		t.Errorf("expected MIME type application/pdf, got %s", result.Attachments[0].MIMEType)
	}
	if result.Attachments[0].Size == 0 {
		t.Error("expected non-zero attachment size")
	}

	// Check second attachment.
	if result.Attachments[1].Filename != "logo.png" {
		t.Errorf("expected filename logo.png, got %s", result.Attachments[1].Filename)
	}
	if result.Attachments[1].MIMEType != "image/png" {
		t.Errorf("expected MIME type image/png, got %s", result.Attachments[1].MIMEType)
	}
}

func TestParseMIME_HTMLOnly(t *testing.T) {
	data := loadTestEmail(t, "html_only.eml")
	result, err := ParseMIME(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.HTMLBody == "" {
		t.Error("expected HTML body")
	}
	if result.TextBody != "" {
		t.Errorf("expected no text body, got %d bytes", len(result.TextBody))
	}

	// Snippet should be generated from stripped HTML.
	if result.Snippet == "" {
		t.Error("expected non-empty snippet generated from HTML")
	}
	if strings.Contains(result.Snippet, "<") {
		t.Error("snippet should not contain HTML tags")
	}
}

func TestParseMIME_LongBody_SnippetTruncation(t *testing.T) {
	data := loadTestEmail(t, "long_body.eml")
	result, err := ParseMIME(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Snippet should be truncated to ~200 chars.
	if len(result.Snippet) > maxSnippetLen+10 { // +10 for "..." and word boundary variance
		t.Errorf("snippet too long: %d chars (max %d)", len(result.Snippet), maxSnippetLen)
	}
	if !strings.HasSuffix(result.Snippet, "...") {
		t.Errorf("expected truncated snippet to end with '...', got: ...%s", result.Snippet[len(result.Snippet)-10:])
	}
}

func TestGenerateSnippet_Empty(t *testing.T) {
	snippet := generateSnippet("", "")
	if snippet != "" {
		t.Errorf("expected empty snippet, got %q", snippet)
	}
}

func TestGenerateSnippet_PrefersText(t *testing.T) {
	snippet := generateSnippet("plain text content", "<p>html content</p>")
	if !strings.Contains(snippet, "plain text content") {
		t.Errorf("expected snippet from text body, got %q", snippet)
	}
}

func TestGenerateSnippet_FallsBackToHTML(t *testing.T) {
	snippet := generateSnippet("", "<p>html only content</p>")
	if !strings.Contains(snippet, "html only content") {
		t.Errorf("expected snippet from stripped HTML, got %q", snippet)
	}
	if strings.Contains(snippet, "<") {
		t.Error("snippet should not contain HTML tags")
	}
}

func TestNormalizeWhitespace(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"hello  world", "hello world"},
		{"line\none\ttwo", "line one two"},
		{"  leading  and  trailing  ", " leading and trailing "},
		{"nochange", "nochange"},
		{"", ""},
	}

	for _, tt := range tests {
		got := normalizeWhitespace(tt.input)
		if got != tt.expected {
			t.Errorf("normalizeWhitespace(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}

func TestStripHTMLBasic(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"<p>hello</p>", " hello "},
		{"<b>bold</b> text", " bold  text"},
		{"no tags here", "no tags here"},
		{"", ""},
		{"<script>evil()</script>", " evil() "},
	}

	for _, tt := range tests {
		got := stripHTMLBasic(tt.input)
		if got != tt.expected {
			t.Errorf("stripHTMLBasic(%q) = %q, want %q", tt.input, got, tt.expected)
		}
	}
}
