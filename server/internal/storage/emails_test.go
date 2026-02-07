package storage

import (
	"context"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// --- Unit tests (no database required) ---

func TestBuildOrderBy(t *testing.T) {
	tests := []struct {
		view     string
		contains string
	}{
		{"action_queue", "COALESCE(ss.return_at, e.received_at) DESC"},
		{"reading_queue", "COALESCE(e.last_read_at, e.received_at) DESC"},
		{"filtered", "CASE WHEN c.confidence < 0.80"},
		{"all_inboxes", "e.received_at DESC"},
	}

	for _, tt := range tests {
		t.Run(tt.view, func(t *testing.T) {
			result := buildOrderBy(tt.view)
			if !containsSubstr(result, tt.contains) {
				t.Errorf("buildOrderBy(%q) = %q, expected to contain %q", tt.view, result, tt.contains)
			}
		})
	}
}

func TestBuildCursor(t *testing.T) {
	now := time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)
	email := &models.Email{
		ID:         "test-id-123",
		ReceivedAt: now,
	}

	cursor := buildCursor("all_inboxes", email)
	if cursor == "" {
		t.Fatal("expected non-empty cursor")
	}

	// Decode and verify
	parts, err := models.DecodeCursor(cursor)
	if err != nil {
		t.Fatalf("DecodeCursor() error: %v", err)
	}
	if len(parts) != 2 {
		t.Fatalf("expected 2 cursor parts, got %d", len(parts))
	}
	if parts[1] != "test-id-123" {
		t.Errorf("expected cursor ID test-id-123, got %s", parts[1])
	}
}

func TestBuildCursorWithSnooze(t *testing.T) {
	now := time.Date(2026, 1, 15, 12, 0, 0, 0, time.UTC)
	returnAt := time.Date(2026, 1, 16, 9, 0, 0, 0, time.UTC)

	email := &models.Email{
		ID:         "snoozed-id",
		ReceivedAt: now,
		Snooze: &models.SnoozeState{
			IsActive: false,
			ReturnAt: returnAt,
		},
	}

	cursor := buildCursor("action_queue", email)
	parts, err := models.DecodeCursor(cursor)
	if err != nil {
		t.Fatalf("DecodeCursor() error: %v", err)
	}

	// Sort key should be the snooze return_at, not received_at
	if parts[0] != returnAt.UTC().Format(time.RFC3339Nano) {
		t.Errorf("expected sort key to be return_at, got %s", parts[0])
	}
}

func TestEnrichViewFieldsFiltered(t *testing.T) {
	email := &models.Email{
		ReceivedAt: time.Now().Add(-3 * 24 * time.Hour), // 3 days ago
	}

	enrichViewFields(email, "filtered")

	if email.DaysUntilExpiry == nil {
		t.Fatal("expected DaysUntilExpiry to be set")
	}
	if *email.DaysUntilExpiry != 11 {
		t.Errorf("expected 11 days until expiry, got %d", *email.DaysUntilExpiry)
	}
}

func TestEnrichViewFieldsFilteredExpired(t *testing.T) {
	email := &models.Email{
		ReceivedAt: time.Now().Add(-20 * 24 * time.Hour), // 20 days ago
	}

	enrichViewFields(email, "filtered")

	if email.DaysUntilExpiry == nil {
		t.Fatal("expected DaysUntilExpiry to be set")
	}
	if *email.DaysUntilExpiry != 0 {
		t.Errorf("expected 0 days until expiry, got %d", *email.DaysUntilExpiry)
	}
}

func TestEnrichViewFieldsNonFiltered(t *testing.T) {
	email := &models.Email{
		ReceivedAt: time.Now(),
	}

	enrichViewFields(email, "action_queue")

	if email.DaysUntilExpiry != nil {
		t.Error("expected DaysUntilExpiry to be nil for non-filtered view")
	}
}

func TestDerefHelpers(t *testing.T) {
	// Test derefStr
	s := "hello"
	if derefStr(&s) != "hello" {
		t.Error("derefStr with value failed")
	}
	if derefStr(nil) != "" {
		t.Error("derefStr with nil failed")
	}

	// Test derefFloat
	f := 3.14
	if derefFloat(&f) != 3.14 {
		t.Error("derefFloat with value failed")
	}
	if derefFloat(nil) != 0 {
		t.Error("derefFloat with nil failed")
	}

	// Test derefBool
	b := true
	if !derefBool(&b) {
		t.Error("derefBool with value failed")
	}
	if derefBool(nil) {
		t.Error("derefBool with nil failed")
	}

	// Test derefInt
	i := 42
	if derefInt(&i) != 42 {
		t.Error("derefInt with value failed")
	}
	if derefInt(nil) != 0 {
		t.Error("derefInt with nil failed")
	}

	// Test derefTime
	now := time.Now()
	if derefTime(&now) != now {
		t.Error("derefTime with value failed")
	}
	if !derefTime(nil).IsZero() {
		t.Error("derefTime with nil failed")
	}
}

// --- Integration tests (require a running PostgreSQL) ---

func setupTestData(t *testing.T, ctx context.Context, store *EmailStore) (accountID string) {
	t.Helper()

	// Create a test account
	err := store.pool.QueryRow(ctx,
		`INSERT INTO accounts (name, email, provider, account_type, color)
		 VALUES ('Test', 'test@example.com', 'test', 'personal', '#FF0000')
		 RETURNING id`,
	).Scan(&accountID)
	if err != nil {
		t.Fatalf("create test account: %v", err)
	}

	return accountID
}

func cleanupAllTestData(t *testing.T, store *EmailStore) {
	t.Helper()
	ctx := context.Background()
	_, _ = store.pool.Exec(ctx, "DELETE FROM snooze_states")
	_, _ = store.pool.Exec(ctx, "DELETE FROM classifications")
	_, _ = store.pool.Exec(ctx, "DELETE FROM emails")
	_, _ = store.pool.Exec(ctx, "DELETE FROM accounts")
}

func createTestEmail(t *testing.T, ctx context.Context, store *EmailStore, accountID string, subject string) *models.Email {
	t.Helper()
	email := &models.Email{
		AccountID:      accountID,
		MessageID:      "msg-" + subject,
		From:           models.Contact{Email: "sender@example.com", Name: "Sender"},
		To:             []models.Contact{{Email: "test@example.com", Name: "Test"}},
		Subject:        subject,
		Snippet:        "Preview of " + subject,
		ReceivedAt:     time.Now().UTC().Truncate(time.Microsecond),
		HasAttachments: false,
	}

	created, err := store.CreateEmail(ctx, email, "<p>Body</p>", "Body")
	if err != nil {
		t.Fatalf("CreateEmail(%q): %v", subject, err)
	}
	return created
}

func addClassification(t *testing.T, ctx context.Context, store *EmailStore, emailID, class string, confidence float64) {
	t.Helper()
	_, err := store.pool.Exec(ctx,
		`INSERT INTO classifications (email_id, classification, confidence, classified_by)
		 VALUES ($1, $2, $3, 'rules')`,
		emailID, class, confidence,
	)
	if err != nil {
		t.Fatalf("add classification: %v", err)
	}
}

func TestIntegrationCreateEmail(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	// Ensure migrations are run
	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	email := &models.Email{
		AccountID:      accountID,
		MessageID:      "test-msg-id-1",
		ThreadID:       "thread-1",
		From:           models.Contact{Email: "alice@example.com", Name: "Alice"},
		To:             []models.Contact{{Email: "test@example.com", Name: "Test User"}},
		CC:             []models.Contact{{Email: "bob@example.com", Name: "Bob"}},
		Subject:        "Test Subject",
		Snippet:        "This is a test email...",
		ReceivedAt:     time.Now().UTC().Truncate(time.Microsecond),
		HasAttachments: true,
		Labels:         []string{"important"},
	}

	created, err := store.CreateEmail(ctx, email, "<p>HTML body</p>", "Text body")
	if err != nil {
		t.Fatalf("CreateEmail() error: %v", err)
	}

	if created.ID == "" {
		t.Error("expected generated ID")
	}
	if created.Subject != "Test Subject" {
		t.Errorf("expected subject 'Test Subject', got %q", created.Subject)
	}
}

func TestIntegrationGetEmail(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)
	created := createTestEmail(t, ctx, store, accountID, "Get Test")
	addClassification(t, ctx, store, created.ID, models.ClassActionRequired, 0.95)

	fetched, err := store.GetEmail(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetEmail() error: %v", err)
	}

	if fetched.ID != created.ID {
		t.Errorf("expected ID %s, got %s", created.ID, fetched.ID)
	}
	if fetched.Subject != "Get Test" {
		t.Errorf("expected subject 'Get Test', got %q", fetched.Subject)
	}
	if fetched.AccountColor != "#FF0000" {
		t.Errorf("expected account color #FF0000, got %s", fetched.AccountColor)
	}
	if fetched.AccountName != "Test" {
		t.Errorf("expected account name 'Test', got %s", fetched.AccountName)
	}
	if fetched.Classification == nil {
		t.Fatal("expected classification to be present")
	}
	if fetched.Classification.Classification != models.ClassActionRequired {
		t.Errorf("expected classification action_required, got %s", fetched.Classification.Classification)
	}
}

func TestIntegrationGetEmailNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)

	_, err := store.GetEmail(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Fatal("expected error for non-existent email")
	}
}

func TestIntegrationGetEmailDetail(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	email := &models.Email{
		AccountID:  accountID,
		From:       models.Contact{Email: "sender@example.com"},
		To:         []models.Contact{{Email: "test@example.com"}},
		Subject:    "Detail Test",
		Snippet:    "Detail snippet",
		ReceivedAt: time.Now().UTC().Truncate(time.Microsecond),
	}

	created, err := store.CreateEmail(ctx, email, "<p>Full HTML</p>", "Plain text body")
	if err != nil {
		t.Fatalf("CreateEmail() error: %v", err)
	}

	detail, err := store.GetEmailDetail(ctx, created.ID)
	if err != nil {
		t.Fatalf("GetEmailDetail() error: %v", err)
	}

	if detail.HTMLBody != "<p>Full HTML</p>" {
		t.Errorf("expected HTML body '<p>Full HTML</p>', got %q", detail.HTMLBody)
	}
	if detail.TextBody != "Plain text body" {
		t.Errorf("expected text body 'Plain text body', got %q", detail.TextBody)
	}
	if detail.Email.Subject != "Detail Test" {
		t.Errorf("expected subject 'Detail Test', got %q", detail.Email.Subject)
	}
}

func TestIntegrationListEmailsAllInboxes(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	// Create 3 emails with different timestamps
	for i := 0; i < 3; i++ {
		email := &models.Email{
			AccountID:  accountID,
			MessageID:  "list-msg-" + time.Now().Format(time.RFC3339Nano),
			From:       models.Contact{Email: "sender@example.com"},
			To:         []models.Contact{{Email: "test@example.com"}},
			Subject:    "List Email " + string(rune('A'+i)),
			Snippet:    "snippet",
			ReceivedAt: time.Now().UTC().Add(time.Duration(-i) * time.Hour).Truncate(time.Microsecond),
		}
		if _, err := store.CreateEmail(ctx, email, "", ""); err != nil {
			t.Fatalf("CreateEmail: %v", err)
		}
		// Add classification so the JOIN works
		addClassification(t, ctx, store, email.ID, models.ClassActionRequired, 0.9)
	}

	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:  "all_inboxes",
		Limit: 10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 3 {
		t.Errorf("expected 3 emails, got %d", len(resp.Data))
	}
	if resp.HasMore {
		t.Error("expected HasMore=false with 3 items and limit=10")
	}

	// Verify ordering: most recent first
	for i := 1; i < len(resp.Data); i++ {
		if resp.Data[i].ReceivedAt.After(resp.Data[i-1].ReceivedAt) {
			t.Errorf("emails not in DESC order at index %d", i)
		}
	}
}

func TestIntegrationListEmailsActionQueue(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	// Create action_required and newsletter emails
	actionEmail := createTestEmail(t, ctx, store, accountID, "Action Email")
	addClassification(t, ctx, store, actionEmail.ID, models.ClassActionRequired, 0.95)

	newsletterEmail := createTestEmail(t, ctx, store, accountID, "Newsletter Email")
	addClassification(t, ctx, store, newsletterEmail.ID, models.ClassNewsletter, 0.90)

	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:  "action_queue",
		Limit: 10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 action_required email, got %d", len(resp.Data))
	}
	if len(resp.Data) > 0 && resp.Data[0].Subject != "Action Email" {
		t.Errorf("expected 'Action Email', got %q", resp.Data[0].Subject)
	}
}

func TestIntegrationListEmailsFiltered(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	// Create filtered emails with different confidence levels
	borderline := createTestEmail(t, ctx, store, accountID, "Borderline Email")
	addClassification(t, ctx, store, borderline.ID, models.ClassFiltered, 0.65)

	standard := createTestEmail(t, ctx, store, accountID, "Standard Filtered")
	addClassification(t, ctx, store, standard.ID, models.ClassFiltered, 0.95)

	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:  "filtered",
		Limit: 10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Fatalf("expected 2 filtered emails, got %d", len(resp.Data))
	}

	// Borderline should come first
	if resp.Data[0].Subject != "Borderline Email" {
		t.Errorf("expected borderline email first, got %q", resp.Data[0].Subject)
	}

	// days_until_expiry should be set
	if resp.Data[0].DaysUntilExpiry == nil {
		t.Error("expected DaysUntilExpiry to be set for filtered emails")
	}
}

func TestIntegrationListEmailsPagination(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	// Create 5 emails
	for i := 0; i < 5; i++ {
		email := &models.Email{
			AccountID:  accountID,
			MessageID:  "page-msg-" + time.Now().Format(time.RFC3339Nano),
			From:       models.Contact{Email: "sender@example.com"},
			To:         []models.Contact{{Email: "test@example.com"}},
			Subject:    "Page Email",
			Snippet:    "snippet",
			ReceivedAt: time.Now().UTC().Add(time.Duration(-i) * time.Hour).Truncate(time.Microsecond),
		}
		created, err := store.CreateEmail(ctx, email, "", "")
		if err != nil {
			t.Fatalf("CreateEmail: %v", err)
		}
		addClassification(t, ctx, store, created.ID, models.ClassActionRequired, 0.9)
	}

	// Page 1: limit 2
	page1, err := store.ListEmails(ctx, EmailListOptions{
		View:  "all_inboxes",
		Limit: 2,
	})
	if err != nil {
		t.Fatalf("ListEmails page 1 error: %v", err)
	}

	if len(page1.Data) != 2 {
		t.Fatalf("expected 2 emails on page 1, got %d", len(page1.Data))
	}
	if !page1.HasMore {
		t.Error("expected HasMore=true on page 1")
	}
	if page1.NextCursor == "" {
		t.Fatal("expected NextCursor on page 1")
	}

	// Page 2: use cursor
	page2, err := store.ListEmails(ctx, EmailListOptions{
		View:   "all_inboxes",
		Limit:  2,
		Cursor: page1.NextCursor,
	})
	if err != nil {
		t.Fatalf("ListEmails page 2 error: %v", err)
	}

	if len(page2.Data) != 2 {
		t.Fatalf("expected 2 emails on page 2, got %d", len(page2.Data))
	}
	if !page2.HasMore {
		t.Error("expected HasMore=true on page 2")
	}

	// Page 3: last page
	page3, err := store.ListEmails(ctx, EmailListOptions{
		View:   "all_inboxes",
		Limit:  2,
		Cursor: page2.NextCursor,
	})
	if err != nil {
		t.Fatalf("ListEmails page 3 error: %v", err)
	}

	if len(page3.Data) != 1 {
		t.Errorf("expected 1 email on page 3, got %d", len(page3.Data))
	}
	if page3.HasMore {
		t.Error("expected HasMore=false on page 3")
	}

	// No overlap between pages
	ids := make(map[string]bool)
	for _, e := range page1.Data {
		ids[e.ID] = true
	}
	for _, e := range page2.Data {
		if ids[e.ID] {
			t.Errorf("page 2 contains duplicate ID %s from page 1", e.ID)
		}
		ids[e.ID] = true
	}
	for _, e := range page3.Data {
		if ids[e.ID] {
			t.Errorf("page 3 contains duplicate ID %s from earlier pages", e.ID)
		}
	}
}

func TestIntegrationListEmailsAccountFilter(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	// Create two accounts
	acct1 := setupTestData(t, ctx, store)
	var acct2 string
	err := store.pool.QueryRow(ctx,
		`INSERT INTO accounts (name, email, provider, account_type, color)
		 VALUES ('Work', 'work@example.com', 'test', 'work', '#0000FF')
		 RETURNING id`,
	).Scan(&acct2)
	if err != nil {
		t.Fatalf("create second account: %v", err)
	}

	e1 := createTestEmail(t, ctx, store, acct1, "Personal Email")
	addClassification(t, ctx, store, e1.ID, models.ClassActionRequired, 0.9)

	e2 := createTestEmail(t, ctx, store, acct2, "Work Email")
	addClassification(t, ctx, store, e2.ID, models.ClassActionRequired, 0.9)

	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:      "all_inboxes",
		AccountID: acct1,
		Limit:     10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 email for account filter, got %d", len(resp.Data))
	}
	if len(resp.Data) > 0 && resp.Data[0].Subject != "Personal Email" {
		t.Errorf("expected 'Personal Email', got %q", resp.Data[0].Subject)
	}
}

func TestIntegrationUpdateEmail(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)
	created := createTestEmail(t, ctx, store, accountID, "Update Test")
	addClassification(t, ctx, store, created.ID, models.ClassActionRequired, 0.9)

	isRead := true
	updated, err := store.UpdateEmail(ctx, created.ID, models.EmailUpdateRequest{
		IsRead: &isRead,
	})
	if err != nil {
		t.Fatalf("UpdateEmail() error: %v", err)
	}

	if !updated.IsRead {
		t.Error("expected is_read=true after update")
	}
	if updated.LastReadAt == nil {
		t.Error("expected last_read_at to be set when marking as read")
	}
}

func TestIntegrationUpdateEmailArchive(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)
	created := createTestEmail(t, ctx, store, accountID, "Archive Test")
	addClassification(t, ctx, store, created.ID, models.ClassActionRequired, 0.9)

	isArchived := true
	updated, err := store.UpdateEmail(ctx, created.ID, models.EmailUpdateRequest{
		IsArchived: &isArchived,
	})
	if err != nil {
		t.Fatalf("UpdateEmail() error: %v", err)
	}

	if !updated.IsArchived {
		t.Error("expected is_archived=true after update")
	}
}

func TestIntegrationUpdateEmailNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)

	isRead := true
	_, err := store.UpdateEmail(ctx, "00000000-0000-0000-0000-000000000000", models.EmailUpdateRequest{
		IsRead: &isRead,
	})
	if err == nil {
		t.Fatal("expected error for non-existent email")
	}
}

func TestIntegrationDeleteEmail(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)
	created := createTestEmail(t, ctx, store, accountID, "Delete Test")

	err := store.DeleteEmail(ctx, created.ID)
	if err != nil {
		t.Fatalf("DeleteEmail() error: %v", err)
	}

	// Verify it's gone
	_, err = store.GetEmail(ctx, created.ID)
	if err == nil {
		t.Error("expected error after deletion")
	}
}

func TestIntegrationDeleteEmailNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)

	err := store.DeleteEmail(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Fatal("expected error for non-existent email")
	}
}

func TestIntegrationCountEmailsByView(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	// Create emails with different classifications
	e1 := createTestEmail(t, ctx, store, accountID, "Action 1")
	addClassification(t, ctx, store, e1.ID, models.ClassActionRequired, 0.95)

	e2 := createTestEmail(t, ctx, store, accountID, "Action 2")
	addClassification(t, ctx, store, e2.ID, models.ClassActionRequired, 0.90)

	e3 := createTestEmail(t, ctx, store, accountID, "Newsletter 1")
	addClassification(t, ctx, store, e3.ID, models.ClassNewsletter, 0.85)

	e4 := createTestEmail(t, ctx, store, accountID, "Filtered Borderline")
	addClassification(t, ctx, store, e4.ID, models.ClassFiltered, 0.70)

	e5 := createTestEmail(t, ctx, store, accountID, "Filtered Standard")
	addClassification(t, ctx, store, e5.ID, models.ClassFiltered, 0.95)

	counts, err := store.CountEmailsByView(ctx, accountID)
	if err != nil {
		t.Fatalf("CountEmailsByView() error: %v", err)
	}

	if counts.ActionQueue != 2 {
		t.Errorf("expected ActionQueue=2, got %d", counts.ActionQueue)
	}
	if counts.ReadingQueue != 1 {
		t.Errorf("expected ReadingQueue=1, got %d", counts.ReadingQueue)
	}
	if counts.Filtered != 2 {
		t.Errorf("expected Filtered=2, got %d", counts.Filtered)
	}
	if counts.FilteredBorderline != 1 {
		t.Errorf("expected FilteredBorderline=1, got %d", counts.FilteredBorderline)
	}
	if counts.AllInboxes != 5 {
		t.Errorf("expected AllInboxes=5, got %d", counts.AllInboxes)
	}
}

func TestIntegrationListEmailsIsReadFilter(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)

	e1 := createTestEmail(t, ctx, store, accountID, "Unread Email")
	addClassification(t, ctx, store, e1.ID, models.ClassActionRequired, 0.9)

	e2 := createTestEmail(t, ctx, store, accountID, "Read Email")
	addClassification(t, ctx, store, e2.ID, models.ClassActionRequired, 0.9)
	isRead := true
	if _, err := store.UpdateEmail(ctx, e2.ID, models.EmailUpdateRequest{IsRead: &isRead}); err != nil {
		t.Fatalf("UpdateEmail: %v", err)
	}

	unread := false
	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:   "all_inboxes",
		IsRead: &unread,
		Limit:  10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("expected 1 unread email, got %d", len(resp.Data))
	}
	if len(resp.Data) > 0 && resp.Data[0].Subject != "Unread Email" {
		t.Errorf("expected 'Unread Email', got %q", resp.Data[0].Subject)
	}
}

func TestIntegrationListEmailsInvalidView(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)

	_, err := store.ListEmails(ctx, EmailListOptions{
		View:  "invalid_view",
		Limit: 10,
	})
	if err == nil {
		t.Fatal("expected error for invalid view")
	}
}

func TestIntegrationListEmailsEmptyResult(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	resp, err := store.ListEmails(ctx, EmailListOptions{
		View:      "all_inboxes",
		AccountID: "00000000-0000-0000-0000-000000000000",
		Limit:     10,
	})
	if err != nil {
		t.Fatalf("ListEmails() error: %v", err)
	}

	if len(resp.Data) != 0 {
		t.Errorf("expected 0 emails, got %d", len(resp.Data))
	}
	if resp.HasMore {
		t.Error("expected HasMore=false")
	}
	if resp.Data == nil {
		t.Error("expected non-nil Data slice (empty, not nil)")
	}
}

func TestIntegrationUpdateEmailNoOp(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewEmailStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, store) })

	accountID := setupTestData(t, ctx, store)
	created := createTestEmail(t, ctx, store, accountID, "NoOp Test")
	addClassification(t, ctx, store, created.ID, models.ClassActionRequired, 0.9)

	// Empty update should return current email
	result, err := store.UpdateEmail(ctx, created.ID, models.EmailUpdateRequest{})
	if err != nil {
		t.Fatalf("UpdateEmail() error: %v", err)
	}
	if result.ID != created.ID {
		t.Errorf("expected ID %s, got %s", created.ID, result.ID)
	}
}
