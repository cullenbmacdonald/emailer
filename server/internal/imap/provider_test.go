package imap

import (
	"testing"
)

func TestDefaultProviderConfig_Gmail(t *testing.T) {
	cfg, err := DefaultProviderConfig(ProviderGmail)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.IMAPHost != "imap.gmail.com" {
		t.Errorf("expected imap.gmail.com, got %s", cfg.IMAPHost)
	}
	if cfg.IMAPPort != 993 {
		t.Errorf("expected port 993, got %d", cfg.IMAPPort)
	}
	if cfg.SMTPHost != "smtp.gmail.com" {
		t.Errorf("expected smtp.gmail.com, got %s", cfg.SMTPHost)
	}
	if cfg.AuthMethod != AuthMethodXOAuth2 {
		t.Errorf("expected %s auth, got %s", AuthMethodXOAuth2, cfg.AuthMethod)
	}
	if !cfg.AutoSaveSent {
		t.Error("expected AutoSaveSent=true for Gmail")
	}
	if !cfg.SupportsGmailExtensions {
		t.Error("expected SupportsGmailExtensions=true for Gmail")
	}
}

func TestDefaultProviderConfig_ICloud(t *testing.T) {
	cfg, err := DefaultProviderConfig(ProviderICloud)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.IMAPHost != "imap.mail.me.com" {
		t.Errorf("expected imap.mail.me.com, got %s", cfg.IMAPHost)
	}
	if cfg.AuthMethod != AuthMethodPlain {
		t.Errorf("expected %s auth, got %s", AuthMethodPlain, cfg.AuthMethod)
	}
	if cfg.AutoSaveSent {
		t.Error("expected AutoSaveSent=false for iCloud")
	}
}

func TestDefaultProviderConfig_Microsoft(t *testing.T) {
	cfg, err := DefaultProviderConfig(ProviderMicrosoft)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if cfg.IMAPHost != "outlook.office365.com" {
		t.Errorf("expected outlook.office365.com, got %s", cfg.IMAPHost)
	}
	if cfg.AuthMethod != AuthMethodXOAuth2 {
		t.Errorf("expected %s auth, got %s", AuthMethodXOAuth2, cfg.AuthMethod)
	}
}

func TestDefaultProviderConfig_Unsupported(t *testing.T) {
	_, err := DefaultProviderConfig("yahoo")
	if err == nil {
		t.Fatal("expected error for unsupported provider")
	}
}

func TestProviderConfig_IMAPAddress(t *testing.T) {
	cfg := &ProviderConfig{
		IMAPHost: "imap.example.com",
		IMAPPort: 993,
	}
	if got := cfg.IMAPAddress(); got != "imap.example.com:993" {
		t.Errorf("expected imap.example.com:993, got %s", got)
	}
}

func TestMicrosoftTokenURL(t *testing.T) {
	tests := []struct {
		tenantID string
		expected string
	}{
		{"", "https://login.microsoftonline.com/common/oauth2/v2.0/token"},
		{"my-tenant", "https://login.microsoftonline.com/my-tenant/oauth2/v2.0/token"},
	}

	for _, tt := range tests {
		got := MicrosoftTokenURL(tt.tenantID)
		if got != tt.expected {
			t.Errorf("MicrosoftTokenURL(%q) = %s, want %s", tt.tenantID, got, tt.expected)
		}
	}
}
