package classifier

import (
	"context"
	"errors"
	"testing"
	"time"
)

type mockVIPListProvider struct {
	emails []string
	err    error
}

func (m *mockVIPListProvider) ListVIPEmails(_ context.Context) ([]string, error) {
	return m.emails, m.err
}

func TestVIPCache_ExactMatch(t *testing.T) {
	provider := &mockVIPListProvider{
		emails: []string{"boss@company.com", "ceo@example.com"},
	}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		email string
		want  bool
	}{
		{"boss@company.com", true},
		{"BOSS@COMPANY.COM", true},
		{"Boss@Company.Com", true},
		{"ceo@example.com", true},
		{"nobody@company.com", false},
		{"boss@other.com", false},
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			got, err := cache.IsVIP(ctx, tt.email)
			if err != nil {
				t.Fatal(err)
			}
			if got != tt.want {
				t.Errorf("IsVIP(%s) = %v, want %v", tt.email, got, tt.want)
			}
		})
	}
}

func TestVIPCache_DomainMatch(t *testing.T) {
	provider := &mockVIPListProvider{
		emails: []string{"@important-client.com", "@vip.org"},
	}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	tests := []struct {
		email string
		want  bool
	}{
		{"anyone@important-client.com", true},
		{"SOMEONE@IMPORTANT-CLIENT.COM", true},
		{"user@vip.org", true},
		{"user@notvip.org", false},
		{"user@sub.important-client.com", false}, // subdomain does not match
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			got, err := cache.IsVIP(ctx, tt.email)
			if err != nil {
				t.Fatal(err)
			}
			if got != tt.want {
				t.Errorf("IsVIP(%s) = %v, want %v", tt.email, got, tt.want)
			}
		})
	}
}

func TestVIPCache_MixedEntries(t *testing.T) {
	provider := &mockVIPListProvider{
		emails: []string{"boss@company.com", "@vip.org"},
	}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	got, _ := cache.IsVIP(ctx, "boss@company.com")
	if !got {
		t.Error("expected exact match")
	}
	got, _ = cache.IsVIP(ctx, "anyone@vip.org")
	if !got {
		t.Error("expected domain match")
	}
	got, _ = cache.IsVIP(ctx, "stranger@unknown.com")
	if got {
		t.Error("expected no match")
	}
}

func TestVIPCache_RefreshUpdatesEntries(t *testing.T) {
	provider := &mockVIPListProvider{
		emails: []string{"old@example.com"},
	}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	got, _ := cache.IsVIP(ctx, "old@example.com")
	if !got {
		t.Error("expected match before refresh")
	}

	// Update provider data and refresh
	provider.emails = []string{"new@example.com"}
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	got, _ = cache.IsVIP(ctx, "old@example.com")
	if got {
		t.Error("old entry should be gone after refresh")
	}
	got, _ = cache.IsVIP(ctx, "new@example.com")
	if !got {
		t.Error("new entry should be present after refresh")
	}
}

func TestVIPCache_RefreshError(t *testing.T) {
	provider := &mockVIPListProvider{
		err: errors.New("db down"),
	}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	err := cache.Refresh(ctx)
	if err == nil {
		t.Error("expected error from refresh")
	}
}

func TestVIPCache_EmptyEmail(t *testing.T) {
	provider := &mockVIPListProvider{emails: []string{"test@example.com"}}
	cache := NewVIPCache(provider, time.Hour, testLogger())
	ctx := context.Background()
	if err := cache.Refresh(ctx); err != nil {
		t.Fatal(err)
	}

	got, err := cache.IsVIP(ctx, "")
	if err != nil {
		t.Fatal(err)
	}
	if got {
		t.Error("empty email should not be VIP")
	}
}
