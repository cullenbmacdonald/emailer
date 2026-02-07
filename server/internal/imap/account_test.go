package imap

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

func testAccountConfig(provider string) config.AccountConfig {
	return config.AccountConfig{
		ID:          "test-acct-1",
		Name:        "Test Account",
		Email:       "test@example.com",
		Provider:    provider,
		AccountType: "personal",
		Color:       "#FF0000",
		IMAP: config.IMAPConfig{
			Host: "imap.example.com",
			Port: 993,
		},
		AppPassword: "test-password",
		OAuth: config.OAuthConfig{
			ClientID:     "test-client-id",
			ClientSecret: "test-client-secret",
		},
	}
}

func TestNewAccount_ICloud(t *testing.T) {
	acct, err := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if acct.tokenMgr != nil {
		t.Error("expected no token manager for iCloud (uses app password)")
	}

	if acct.provider.AuthMethod != AuthMethodPlain {
		t.Errorf("expected %s auth, got %s", AuthMethodPlain, acct.provider.AuthMethod)
	}

	// Verify config override worked.
	if acct.provider.IMAPHost != "imap.example.com" {
		t.Errorf("expected overridden host, got %s", acct.provider.IMAPHost)
	}
}

func TestNewAccount_Gmail(t *testing.T) {
	acct, err := NewAccount(testAccountConfig(ProviderGmail), zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if acct.tokenMgr == nil {
		t.Error("expected token manager for Gmail")
	}

	if acct.provider.AuthMethod != AuthMethodXOAuth2 {
		t.Errorf("expected %s auth, got %s", AuthMethodXOAuth2, acct.provider.AuthMethod)
	}
}

func TestNewAccount_Microsoft(t *testing.T) {
	acct, err := NewAccount(testAccountConfig(ProviderMicrosoft), zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if acct.tokenMgr == nil {
		t.Error("expected token manager for Microsoft")
	}
}

func TestNewAccount_UnsupportedProvider(t *testing.T) {
	_, err := NewAccount(testAccountConfig("yahoo"), zerolog.Nop())
	if err == nil {
		t.Fatal("expected error for unsupported provider")
	}
}

func TestAccount_Status(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())

	status, msg := acct.Status()
	if status != models.AccountStatusOffline {
		t.Errorf("expected initial status offline, got %s", status)
	}
	if msg != "" {
		t.Errorf("expected empty message, got %s", msg)
	}
}

func TestAccount_SetStatus_TriggersCallback(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())

	var mu sync.Mutex
	var gotID, gotStatus string
	acct.SetStatusChangeCallback(func(accountID, status, _ string) {
		mu.Lock()
		defer mu.Unlock()
		gotID = accountID
		gotStatus = status
	})

	acct.setStatus(models.AccountStatusOnline, "")

	mu.Lock()
	defer mu.Unlock()
	if gotID != "test-acct-1" {
		t.Errorf("expected account ID test-acct-1, got %s", gotID)
	}
	if gotStatus != models.AccountStatusOnline {
		t.Errorf("expected status online, got %s", gotStatus)
	}
}

func TestAccount_SetStatus_NoCallbackOnSameStatus(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())

	callCount := 0
	acct.SetStatusChangeCallback(func(_, _, _ string) {
		callCount++
	})

	acct.setStatus(models.AccountStatusOffline, "") // Same as initial.
	if callCount != 0 {
		t.Errorf("expected no callback for same status, got %d calls", callCount)
	}

	acct.setStatus(models.AccountStatusOnline, "")
	if callCount != 1 {
		t.Errorf("expected 1 callback, got %d", callCount)
	}

	acct.setStatus(models.AccountStatusOnline, "") // Same again.
	if callCount != 1 {
		t.Errorf("expected still 1 callback, got %d", callCount)
	}
}

func TestAccount_SignalNewMail_NonBlocking(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())

	// Signal should not block even without a reader.
	acct.signalNewMail()
	acct.signalNewMail() // Second signal should be dropped (channel is full).

	select {
	case <-acct.newMailCh:
		// Good, got the signal.
	default:
		t.Error("expected signal on newMailCh")
	}

	// Channel should be empty now.
	select {
	case <-acct.newMailCh:
		t.Error("expected no more signals")
	default:
		// Good.
	}
}

func TestAccount_RunWorker_ContextCancellation(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())
	newEmails := make(chan *FetchedEmail, 10)

	ctx, cancel := context.WithCancel(context.Background())

	done := make(chan struct{})
	go func() {
		acct.RunWorker(ctx, newEmails)
		close(done)
	}()

	// Cancel should cause the worker to exit.
	cancel()

	select {
	case <-done:
		// Good.
	case <-time.After(2 * time.Second):
		t.Fatal("RunWorker did not exit after context cancellation")
	}
}

func TestAccount_Config(t *testing.T) {
	cfg := testAccountConfig(ProviderICloud)
	acct, _ := NewAccount(cfg, zerolog.Nop())

	if acct.Config().ID != cfg.ID {
		t.Errorf("expected account ID %s, got %s", cfg.ID, acct.Config().ID)
	}
	if acct.Config().Email != cfg.Email {
		t.Errorf("expected email %s, got %s", cfg.Email, acct.Config().Email)
	}
}

func TestAccount_ProviderCfg(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderGmail), zerolog.Nop())

	if !acct.ProviderCfg().SupportsGmailExtensions {
		t.Error("expected Gmail extensions support")
	}
}

func TestAccount_Close(t *testing.T) {
	acct, _ := NewAccount(testAccountConfig(ProviderICloud), zerolog.Nop())

	// Close should not panic.
	acct.Close()
}
