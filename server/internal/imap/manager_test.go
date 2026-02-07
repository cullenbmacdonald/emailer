package imap

import (
	"context"
	"testing"
	"time"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

func testAccounts() []config.AccountConfig {
	return []config.AccountConfig{
		{
			ID:          "gmail-1",
			Name:        "Gmail Personal",
			Email:       "user@gmail.com",
			Provider:    ProviderGmail,
			AccountType: "personal",
			Color:       "#4285F4",
			IMAP:        config.IMAPConfig{Host: "imap.gmail.com", Port: 993},
			OAuth:       config.OAuthConfig{ClientID: "test-id", ClientSecret: "test-secret"},
			AppPassword: "test-refresh-token",
		},
		{
			ID:          "icloud-1",
			Name:        "iCloud Mail",
			Email:       "user@icloud.com",
			Provider:    ProviderICloud,
			AccountType: "personal",
			Color:       "#007AFF",
			IMAP:        config.IMAPConfig{Host: "imap.mail.me.com", Port: 993},
			AppPassword: "test-app-password",
		},
		{
			ID:          "ms-1",
			Name:        "Work Outlook",
			Email:       "user@company.com",
			Provider:    ProviderMicrosoft,
			AccountType: "work",
			Color:       "#00A4EF",
			IMAP:        config.IMAPConfig{Host: "outlook.office365.com", Port: 993},
			OAuth:       config.OAuthConfig{ClientID: "test-id", ClientSecret: "test-secret", TenantID: "test-tenant"},
			AppPassword: "test-refresh-token",
		},
	}
}

func TestNewManager(t *testing.T) {
	mgr, err := NewManager(testAccounts(), zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if mgr.AccountCount() != 3 {
		t.Errorf("expected 3 accounts, got %d", mgr.AccountCount())
	}

	// Verify accounts are accessible.
	acct, ok := mgr.Account("gmail-1")
	if !ok {
		t.Fatal("expected gmail-1 account")
	}
	if acct.Config().Email != "user@gmail.com" {
		t.Errorf("expected user@gmail.com, got %s", acct.Config().Email)
	}
}

func TestNewManager_InvalidProvider(t *testing.T) {
	accounts := []config.AccountConfig{
		{
			ID:       "bad-1",
			Name:     "Bad Account",
			Email:    "user@bad.com",
			Provider: "unsupported",
		},
	}

	_, err := NewManager(accounts, zerolog.Nop())
	if err == nil {
		t.Fatal("expected error for unsupported provider")
	}
}

func TestNewManager_EmptyAccounts(t *testing.T) {
	mgr, err := NewManager(nil, zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if mgr.AccountCount() != 0 {
		t.Errorf("expected 0 accounts, got %d", mgr.AccountCount())
	}
}

func TestManager_AccountStatuses(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	statuses := mgr.AccountStatuses()
	if len(statuses) != 3 {
		t.Errorf("expected 3 statuses, got %d", len(statuses))
	}

	for id, acct := range statuses {
		if acct.Status != models.AccountStatusOffline {
			t.Errorf("account %s: expected offline status, got %s", id, acct.Status)
		}
	}

	// Verify account metadata is populated.
	gmail := statuses["gmail-1"]
	if gmail.Name != "Gmail Personal" {
		t.Errorf("expected name 'Gmail Personal', got %s", gmail.Name)
	}
	if gmail.EmailAddress != "user@gmail.com" {
		t.Errorf("expected email user@gmail.com, got %s", gmail.EmailAddress)
	}
	if gmail.Color != "#4285F4" {
		t.Errorf("expected color #4285F4, got %s", gmail.Color)
	}
	if gmail.AccountType != "personal" {
		t.Errorf("expected type personal, got %s", gmail.AccountType)
	}
}

func TestManager_Account_NotFound(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	_, ok := mgr.Account("nonexistent")
	if ok {
		t.Error("expected account not found")
	}
}

func TestManager_NewEmails_Channel(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	ch := mgr.NewEmails()
	if ch == nil {
		t.Fatal("expected non-nil NewEmails channel")
	}
}

func TestManager_SetStatusChangeCallback(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	callbackCalled := false
	mgr.SetStatusChangeCallback(func(accountID, status, message string) {
		callbackCalled = true
	})

	// Trigger a status change on one of the accounts.
	acct, _ := mgr.Account("icloud-1")
	acct.setStatus(models.AccountStatusOnline, "")

	if !callbackCalled {
		t.Error("expected status change callback to be called")
	}
}

func TestManager_StopWithoutStart(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	// Stop without Start should not panic.
	mgr.Stop()
}

func TestManager_StartAndStop(t *testing.T) {
	// Test with zero accounts to avoid actual IMAP connections.
	mgr, _ := NewManager(nil, zerolog.Nop())

	ctx := context.Background()
	mgr.Start(ctx)

	// Give goroutines a moment to start.
	time.Sleep(10 * time.Millisecond)

	mgr.Stop()
}
