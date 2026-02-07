package imap

import (
	"errors"
	"testing"
)

func TestXOAuth2Client_Start(t *testing.T) {
	client := NewXOAuth2Client("user@gmail.com", "access-token-123")

	mech, ir, err := client.Start()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if mech != "XOAUTH2" {
		t.Errorf("expected mechanism XOAUTH2, got %s", mech)
	}

	expected := "user=user@gmail.com\x01auth=Bearer access-token-123\x01\x01"
	if string(ir) != expected {
		t.Errorf("expected IR %q, got %q", expected, string(ir))
	}
}

func TestXOAuth2Client_Next_ReturnsAuthError(t *testing.T) {
	client := NewXOAuth2Client("user@gmail.com", "bad-token")

	_, _, _ = client.Start()

	challenge := []byte(`{"error":"invalid_token"}`)
	_, err := client.Next(challenge)
	if err == nil {
		t.Fatal("expected error from Next")
	}

	var authErr *AuthError
	if !errors.As(err, &authErr) {
		t.Fatalf("expected *AuthError, got %T: %v", err, err)
	}
	if authErr.Recoverable {
		t.Error("expected non-recoverable auth error")
	}
}
