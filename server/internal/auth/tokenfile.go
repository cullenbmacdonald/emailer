// Package auth provides OAuth2 token file utilities for the CLI token-auth command.
package auth

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// TokenFile is the JSON structure saved to disk for OAuth2 tokens.
// This format is read by the IMAP package to initialize the OAuthTokenManager.
type TokenFile struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	TokenType    string    `json:"token_type"`
	Expiry       time.Time `json:"expiry"`
}

// SaveTokenFile writes a TokenFile as JSON to the given path, creating parent directories.
func SaveTokenFile(path string, tf *TokenFile) error {
	// Expand ~ if present.
	if len(path) > 0 && path[0] == '~' {
		home, err := os.UserHomeDir()
		if err != nil {
			return fmt.Errorf("expand home dir: %w", err)
		}
		path = filepath.Join(home, path[1:])
	}

	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("create token directory %s: %w", dir, err)
	}

	data, err := json.MarshalIndent(tf, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal token: %w", err)
	}

	if err := os.WriteFile(path, data, 0600); err != nil {
		return fmt.Errorf("write token file %s: %w", path, err)
	}

	return nil
}

// LoadTokenFile reads a TokenFile from disk.
func LoadTokenFile(path string) (*TokenFile, error) {
	if len(path) > 0 && path[0] == '~' {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("expand home dir: %w", err)
		}
		path = filepath.Join(home, path[1:])
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read token file %s: %w", path, err)
	}

	var tf TokenFile
	if err := json.Unmarshal(data, &tf); err != nil {
		return nil, fmt.Errorf("parse token file %s: %w", path, err)
	}

	return &tf, nil
}
