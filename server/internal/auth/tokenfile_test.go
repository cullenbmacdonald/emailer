package auth

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSaveAndLoadTokenFile(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "subdir", "token.json")

	expiry := time.Date(2025, 6, 15, 12, 0, 0, 0, time.UTC)
	tf := &TokenFile{
		AccessToken:  "access-123",
		RefreshToken: "refresh-456",
		TokenType:    "Bearer",
		Expiry:       expiry,
	}

	if err := SaveTokenFile(path, tf); err != nil {
		t.Fatalf("SaveTokenFile: %v", err)
	}

	// Verify file permissions.
	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if perm := info.Mode().Perm(); perm != 0600 {
		t.Errorf("expected 0600 permissions, got %o", perm)
	}

	// Load and verify.
	loaded, err := LoadTokenFile(path)
	if err != nil {
		t.Fatalf("LoadTokenFile: %v", err)
	}

	if loaded.AccessToken != tf.AccessToken {
		t.Errorf("access_token: got %q, want %q", loaded.AccessToken, tf.AccessToken)
	}
	if loaded.RefreshToken != tf.RefreshToken {
		t.Errorf("refresh_token: got %q, want %q", loaded.RefreshToken, tf.RefreshToken)
	}
	if loaded.TokenType != tf.TokenType {
		t.Errorf("token_type: got %q, want %q", loaded.TokenType, tf.TokenType)
	}
	if !loaded.Expiry.Equal(tf.Expiry) {
		t.Errorf("expiry: got %v, want %v", loaded.Expiry, tf.Expiry)
	}
}

func TestTokenFileJSONFormat(t *testing.T) {
	// Verify the JSON format matches what we expect for compatibility.
	tf := &TokenFile{
		AccessToken:  "abc",
		RefreshToken: "def",
		TokenType:    "Bearer",
		Expiry:       time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
	}

	data, err := json.Marshal(tf)
	if err != nil {
		t.Fatal(err)
	}

	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}

	// Check expected keys exist.
	for _, key := range []string{"access_token", "refresh_token", "token_type", "expiry"} {
		if _, ok := m[key]; !ok {
			t.Errorf("missing expected JSON key %q", key)
		}
	}

	// Should have exactly 4 keys.
	if len(m) != 4 {
		t.Errorf("expected 4 JSON keys, got %d: %v", len(m), m)
	}
}

func TestLoadTokenFile_NotFound(t *testing.T) {
	_, err := LoadTokenFile("/nonexistent/path/token.json")
	if err == nil {
		t.Fatal("expected error for missing file")
	}
}

func TestSaveTokenFile_CreatesParentDirs(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "a", "b", "c", "token.json")

	tf := &TokenFile{AccessToken: "test"}
	if err := SaveTokenFile(path, tf); err != nil {
		t.Fatalf("SaveTokenFile: %v", err)
	}

	if _, err := os.Stat(path); err != nil {
		t.Fatalf("file not created: %v", err)
	}
}
