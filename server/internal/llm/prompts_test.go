package llm

import (
	"strings"
	"testing"
)

func TestBuildClassificationPrompt(t *testing.T) {
	prompt := BuildClassificationPrompt(ClassifyRequest{
		Subject:    "Can you review this?",
		From:       "alice@example.com",
		FromName:   "Alice",
		ToPosition: "to",
		Body:       "Please review the attached document.",
	})

	if !strings.Contains(prompt, "Can you review this?") {
		t.Error("prompt missing subject")
	}
	if !strings.Contains(prompt, "Alice") {
		t.Error("prompt missing from name")
	}
	if !strings.Contains(prompt, "alice@example.com") {
		t.Error("prompt missing from email")
	}
	if !strings.Contains(prompt, "Please review") {
		t.Error("prompt missing body")
	}
}

func TestBuildClassificationPrompt_Truncates(t *testing.T) {
	longBody := strings.Repeat("a", 3000)
	prompt := BuildClassificationPrompt(ClassifyRequest{
		Subject: "test",
		Body:    longBody,
	})
	// The prompt should not contain the full 3000-char body
	if strings.Contains(prompt, strings.Repeat("a", 2001)) {
		t.Error("prompt body was not truncated")
	}
}

func TestBuildExtractionPrompt(t *testing.T) {
	prompt := BuildExtractionPrompt(ExtractRequest{
		Subject: "Weekly Newsletter",
		From:    "news@example.com",
		Body:    "Check out this book: Dune by Frank Herbert.",
	})
	if !strings.Contains(prompt, "Weekly Newsletter") {
		t.Error("prompt missing subject")
	}
	if !strings.Contains(prompt, "Dune") {
		t.Error("prompt missing body content")
	}
}
