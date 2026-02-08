package smtp

import (
	"context"
	"strings"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog"
)

func TestBuildMessage_Basic(t *testing.T) {
	acct := config.AccountConfig{
		Name:  "Test User",
		Email: "test@example.com",
		SMTP:  config.SMTPConfig{Host: "smtp.example.com", Port: 587},
	}
	compose := models.ComposeRequest{
		To:      []string{"recipient@example.com"},
		Subject: "Hello",
		Body:    "World",
	}

	msg := buildMessage(acct, compose, "<msg-id@smtp.example.com>")

	if !strings.Contains(msg, "From: Test User <test@example.com>") {
		t.Error("missing From header")
	}
	if !strings.Contains(msg, "To: recipient@example.com") {
		t.Error("missing To header")
	}
	if !strings.Contains(msg, "Subject: Hello") {
		t.Error("missing Subject header")
	}
	if !strings.Contains(msg, "Message-ID: <msg-id@smtp.example.com>") {
		t.Error("missing Message-ID header")
	}
	if !strings.Contains(msg, "Content-Type: text/plain; charset=UTF-8") {
		t.Error("expected text/plain content type")
	}
	if !strings.Contains(msg, "World") {
		t.Error("missing body")
	}
}

func TestBuildMessage_HTML(t *testing.T) {
	acct := config.AccountConfig{Email: "test@example.com"}
	compose := models.ComposeRequest{
		To:       []string{"r@example.com"},
		Subject:  "Hi",
		HTMLBody: "<p>Hello</p>",
	}

	msg := buildMessage(acct, compose, "<id@host>")

	if !strings.Contains(msg, "Content-Type: text/html; charset=UTF-8") {
		t.Error("expected text/html content type")
	}
	if !strings.Contains(msg, "<p>Hello</p>") {
		t.Error("missing HTML body")
	}
}

func TestBuildMessage_Reply(t *testing.T) {
	acct := config.AccountConfig{Email: "test@example.com"}
	compose := models.ComposeRequest{
		To:        []string{"r@example.com"},
		Subject:   "Re: Hello",
		Body:      "Reply",
		InReplyTo: "<original@host>",
	}

	msg := buildMessage(acct, compose, "<id@host>")

	if !strings.Contains(msg, "In-Reply-To: <original@host>") {
		t.Error("missing In-Reply-To header")
	}
	if !strings.Contains(msg, "References: <original@host>") {
		t.Error("missing References header")
	}
}

func TestBuildMessage_CC(t *testing.T) {
	acct := config.AccountConfig{Email: "test@example.com"}
	compose := models.ComposeRequest{
		To:      []string{"a@example.com"},
		CC:      []string{"b@example.com", "c@example.com"},
		Subject: "Test",
		Body:    "Body",
	}

	msg := buildMessage(acct, compose, "<id@host>")

	if !strings.Contains(msg, "Cc: b@example.com, c@example.com") {
		t.Error("missing Cc header")
	}
}

func TestBuildMessage_NoBCC(t *testing.T) {
	acct := config.AccountConfig{Email: "test@example.com"}
	compose := models.ComposeRequest{
		To:      []string{"a@example.com"},
		BCC:     []string{"hidden@example.com"},
		Subject: "Test",
		Body:    "Body",
	}

	msg := buildMessage(acct, compose, "<id@host>")

	if strings.Contains(msg, "hidden@example.com") {
		t.Error("BCC should not appear in message headers")
	}
}

func TestFormatAddress(t *testing.T) {
	tests := []struct {
		name, email, want string
	}{
		{"Test User", "test@example.com", "Test User <test@example.com>"},
		{"", "test@example.com", "<test@example.com>"},
	}
	for _, tt := range tests {
		got := formatAddress(tt.name, tt.email)
		if got != tt.want {
			t.Errorf("formatAddress(%q, %q) = %q, want %q", tt.name, tt.email, got, tt.want)
		}
	}
}

func TestNewSender_AccountLookup(t *testing.T) {
	accounts := []config.AccountConfig{
		{ID: "a1", Email: "a1@example.com", SMTP: config.SMTPConfig{Host: "smtp.example.com", Port: 587}},
	}
	s := NewSender(accounts, zerolog.Nop())

	// Unknown account should error.
	_, err := s.Send(context.TODO(), "unknown", models.ComposeRequest{})
	if err == nil {
		t.Error("expected error for unknown account")
	}
}

func TestNewSender_NoSMTPHost(t *testing.T) {
	accounts := []config.AccountConfig{
		{ID: "a1", Email: "a1@example.com"},
	}
	s := NewSender(accounts, zerolog.Nop())

	_, err := s.Send(context.TODO(), "a1", models.ComposeRequest{})
	if err == nil || !strings.Contains(err.Error(), "no SMTP host") {
		t.Errorf("expected 'no SMTP host' error, got: %v", err)
	}
}
