package imap

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/rs/zerolog"
)

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func TestOAuthTokenManager_GetAccessToken_Fresh(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if err := r.ParseForm(); err != nil {
			t.Fatal(err)
		}
		if r.FormValue("grant_type") != "refresh_token" {
			t.Errorf("expected grant_type=refresh_token, got %s", r.FormValue("grant_type"))
		}
		if r.FormValue("client_id") != "test-client-id" {
			t.Errorf("expected client_id=test-client-id, got %s", r.FormValue("client_id"))
		}

		writeJSON(w, tokenResponse{
			AccessToken: "new-access-token",
			TokenType:   "Bearer",
			ExpiresIn:   3600,
		})
	}))
	defer server.Close()

	mgr := NewOAuthTokenManager(OAuthManagerConfig{
		ClientID:     "test-client-id",
		ClientSecret: "test-client-secret",
		RefreshToken: "test-refresh-token",
		TokenURL:     server.URL,
	}, zerolog.Nop())

	token, err := mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if token != "new-access-token" {
		t.Errorf("expected new-access-token, got %s", token)
	}
}

func TestOAuthTokenManager_GetAccessToken_Cached(t *testing.T) {
	callCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		callCount++
		writeJSON(w, tokenResponse{
			AccessToken: "cached-token",
			ExpiresIn:   3600,
		})
	}))
	defer server.Close()

	mgr := NewOAuthTokenManager(OAuthManagerConfig{
		ClientID:     "test-client-id",
		RefreshToken: "test-refresh-token",
		TokenURL:     server.URL,
	}, zerolog.Nop())

	// First call should hit the server.
	_, err := mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Second call should use cached token (no server hit).
	token, err := mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if token != "cached-token" {
		t.Errorf("expected cached-token, got %s", token)
	}
	if callCount != 1 {
		t.Errorf("expected 1 server call, got %d", callCount)
	}
}

func TestOAuthTokenManager_GetAccessToken_RefreshesNearExpiry(t *testing.T) {
	callCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		callCount++
		writeJSON(w, tokenResponse{
			AccessToken: "token-" + time.Now().Format("150405"),
			ExpiresIn:   60, // 1 minute — will be "near expiry" immediately since we check 5min ahead
		})
	}))
	defer server.Close()

	mgr := NewOAuthTokenManager(OAuthManagerConfig{
		ClientID:     "test-client-id",
		RefreshToken: "test-refresh-token",
		TokenURL:     server.URL,
	}, zerolog.Nop())

	// First call.
	_, err := mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Second call should trigger another refresh because the token expires in 60s
	// and we check 5min ahead.
	_, err = mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if callCount != 2 {
		t.Errorf("expected 2 server calls (token near-expiry), got %d", callCount)
	}
}

func TestOAuthTokenManager_GetAccessToken_InvalidGrant(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadRequest)
		writeJSON(w, tokenErrorResponse{
			Error:       "invalid_grant",
			Description: "Token has been revoked",
		})
	}))
	defer server.Close()

	mgr := NewOAuthTokenManager(OAuthManagerConfig{
		ClientID:     "test-client-id",
		RefreshToken: "bad-refresh-token",
		TokenURL:     server.URL,
	}, zerolog.Nop())

	_, err := mgr.GetAccessToken(context.Background())
	if err == nil {
		t.Fatal("expected error for invalid_grant")
	}

	var authErr *AuthError
	if !errors.As(err, &authErr) {
		t.Fatalf("expected *AuthError, got %T: %v", err, err)
	}
	if authErr.Code != "invalid_grant" {
		t.Errorf("expected code invalid_grant, got %s", authErr.Code)
	}
	if authErr.Recoverable {
		t.Error("expected non-recoverable error for invalid_grant")
	}
}

func TestOAuthTokenManager_TokenRotation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, tokenResponse{
			AccessToken:  "new-access-token",
			ExpiresIn:    3600,
			RefreshToken: "rotated-refresh-token",
		})
	}))
	defer server.Close()

	mgr := NewOAuthTokenManager(OAuthManagerConfig{
		ClientID:     "test-client-id",
		RefreshToken: "original-refresh-token",
		TokenURL:     server.URL,
	}, zerolog.Nop())

	_, err := mgr.GetAccessToken(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// Verify the refresh token was rotated.
	mgr.mu.RLock()
	if mgr.refreshToken != "rotated-refresh-token" {
		t.Errorf("expected rotated refresh token, got %s", mgr.refreshToken)
	}
	mgr.mu.RUnlock()
}
