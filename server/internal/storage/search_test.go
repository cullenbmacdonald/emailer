package storage

import (
	"context"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestIntegrationSearchEmails(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	searchStore := NewSearchStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)

	// Create emails with searchable content
	e1 := &models.Email{
		AccountID:  accountID,
		MessageID:  "search-msg-1",
		From:       models.Contact{Email: "alice@example.com", Name: "Alice"},
		To:         []models.Contact{{Email: "test@example.com"}},
		Subject:    "Quarterly budget review needed",
		Snippet:    "Please review the Q3 budget",
		ReceivedAt: time.Now().UTC().Add(-1 * time.Hour).Truncate(time.Microsecond),
	}
	created1, err := emailStore.CreateEmail(ctx, e1, "<p>Please review the Q3 budget report</p>", "Please review the Q3 budget report")
	if err != nil {
		t.Fatalf("CreateEmail 1: %v", err)
	}

	e2 := &models.Email{
		AccountID:  accountID,
		MessageID:  "search-msg-2",
		From:       models.Contact{Email: "bob@example.com", Name: "Bob"},
		To:         []models.Contact{{Email: "test@example.com"}},
		Subject:    "Lunch plans for Friday",
		Snippet:    "Want to grab lunch?",
		ReceivedAt: time.Now().UTC().Truncate(time.Microsecond),
	}
	if _, err := emailStore.CreateEmail(ctx, e2, "<p>Want to grab lunch on Friday?</p>", "Want to grab lunch on Friday?"); err != nil {
		t.Fatalf("CreateEmail 2: %v", err)
	}

	// Search for "budget" - should find email 1
	resp, err := searchStore.SearchEmails(ctx, "budget", "", "", 10)
	if err != nil {
		t.Fatalf("SearchEmails('budget') error: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Fatalf("expected 1 result for 'budget', got %d", len(resp.Data))
	}
	if resp.Data[0].Email.ID != created1.ID {
		t.Errorf("expected email %s, got %s", created1.ID, resp.Data[0].Email.ID)
	}
	if resp.Data[0].HighlightSnippet == "" {
		t.Error("expected non-empty highlight snippet")
	}
	if resp.Query != "budget" {
		t.Errorf("expected query 'budget', got %q", resp.Query)
	}
}

func TestIntegrationSearchEmailsNoResults(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	searchStore := NewSearchStore(pool)

	resp, err := searchStore.SearchEmails(ctx, "xyznonexistent12345", "", "", 10)
	if err != nil {
		t.Fatalf("SearchEmails() error: %v", err)
	}

	if resp.Data == nil {
		t.Error("expected non-nil Data slice")
	}
	if len(resp.Data) != 0 {
		t.Errorf("expected 0 results, got %d", len(resp.Data))
	}
	if resp.HasMore {
		t.Error("expected HasMore=false")
	}
}

func TestIntegrationSearchEmailsAccountFilter(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	searchStore := NewSearchStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	acct1 := setupTestData(t, ctx, emailStore)
	var acct2 string
	err := pool.QueryRow(ctx,
		`INSERT INTO accounts (name, email, provider, account_type, color)
		 VALUES ('Work', 'work@example.com', 'test', 'work', '#0000FF')
		 RETURNING id`,
	).Scan(&acct2)
	if err != nil {
		t.Fatalf("create second account: %v", err)
	}

	// Create "report" emails in both accounts
	e1 := &models.Email{
		AccountID:  acct1,
		MessageID:  "search-acct-1",
		From:       models.Contact{Email: "alice@example.com"},
		To:         []models.Contact{{Email: "test@example.com"}},
		Subject:    "Monthly report summary",
		Snippet:    "Here is the report",
		ReceivedAt: time.Now().UTC().Truncate(time.Microsecond),
	}
	if _, err := emailStore.CreateEmail(ctx, e1, "", "Monthly report attached"); err != nil {
		t.Fatalf("CreateEmail 1: %v", err)
	}

	e2 := &models.Email{
		AccountID:  acct2,
		MessageID:  "search-acct-2",
		From:       models.Contact{Email: "bob@example.com"},
		To:         []models.Contact{{Email: "work@example.com"}},
		Subject:    "Annual report review",
		Snippet:    "Please review the annual report",
		ReceivedAt: time.Now().UTC().Truncate(time.Microsecond),
	}
	if _, err := emailStore.CreateEmail(ctx, e2, "", "Annual report review needed"); err != nil {
		t.Fatalf("CreateEmail 2: %v", err)
	}

	// Search with account filter
	resp, err := searchStore.SearchEmails(ctx, "report", acct1, "", 10)
	if err != nil {
		t.Fatalf("SearchEmails() error: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 result with account filter, got %d", len(resp.Data))
	}
}

func TestJoinAnd(t *testing.T) {
	tests := []struct {
		parts    []string
		expected string
	}{
		{[]string{"a = 1"}, "a = 1"},
		{[]string{"a = 1", "b = 2"}, "a = 1 AND b = 2"},
		{[]string{"a = 1", "b = 2", "c = 3"}, "a = 1 AND b = 2 AND c = 3"},
	}

	for _, tt := range tests {
		result := joinAnd(tt.parts)
		if result != tt.expected {
			t.Errorf("joinAnd(%v) = %q, expected %q", tt.parts, result, tt.expected)
		}
	}
}
