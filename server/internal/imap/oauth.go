package imap

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/rs/zerolog"
)

// tokenResponse is the JSON response from an OAuth2 token endpoint.
type tokenResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token,omitempty"`
	Scope        string `json:"scope,omitempty"`
}

// tokenErrorResponse is the JSON error response from an OAuth2 token endpoint.
type tokenErrorResponse struct {
	Error       string `json:"error"`
	Description string `json:"error_description,omitempty"`
}

// OAuthTokenManager manages OAuth2 access and refresh tokens for a single account.
// It handles proactive token refresh (5 minutes before expiry) and token rotation.
type OAuthTokenManager struct {
	mu           sync.RWMutex
	accessToken  string
	refreshToken string
	expiry       time.Time
	clientID     string
	clientSecret string
	tokenURL     string
	httpClient   *http.Client
	logger       zerolog.Logger
}

// OAuthConfig holds the configuration needed to create a token manager.
type OAuthManagerConfig struct {
	ClientID     string
	ClientSecret string
	RefreshToken string
	TokenURL     string
}

// GmailTokenURL is the Google OAuth2 token endpoint.
const GmailTokenURL = "https://oauth2.googleapis.com/token"

// MicrosoftTokenURL returns the Microsoft OAuth2 token endpoint for a tenant.
func MicrosoftTokenURL(tenantID string) string {
	if tenantID == "" {
		tenantID = "common"
	}
	return fmt.Sprintf("https://login.microsoftonline.com/%s/oauth2/v2.0/token", tenantID)
}

// NewOAuthTokenManager creates a new token manager with the given configuration.
func NewOAuthTokenManager(cfg OAuthManagerConfig, logger zerolog.Logger) *OAuthTokenManager {
	return &OAuthTokenManager{
		refreshToken: cfg.RefreshToken,
		clientID:     cfg.ClientID,
		clientSecret: cfg.ClientSecret,
		tokenURL:     cfg.TokenURL,
		httpClient:   &http.Client{Timeout: 30 * time.Second},
		logger:       logger.With().Str("component", "oauth").Logger(),
	}
}

// GetAccessToken returns a valid access token, refreshing if necessary.
// Proactively refreshes 5 minutes before expiry.
func (m *OAuthTokenManager) GetAccessToken(ctx context.Context) (string, error) {
	m.mu.RLock()
	if m.accessToken != "" && time.Now().Add(5*time.Minute).Before(m.expiry) {
		token := m.accessToken
		m.mu.RUnlock()
		return token, nil
	}
	m.mu.RUnlock()

	return m.refresh(ctx)
}

// refresh performs the OAuth2 token refresh.
func (m *OAuthTokenManager) refresh(ctx context.Context) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Double-check after acquiring write lock (another goroutine may have refreshed).
	if m.accessToken != "" && time.Now().Add(5*time.Minute).Before(m.expiry) {
		return m.accessToken, nil
	}

	m.logger.Debug().Msg("refreshing OAuth2 access token")

	data := url.Values{
		"grant_type":    {"refresh_token"},
		"refresh_token": {m.refreshToken},
		"client_id":     {m.clientID},
	}
	if m.clientSecret != "" {
		data.Set("client_secret", m.clientSecret)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.tokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return "", fmt.Errorf("create token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := m.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("token request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		var errResp tokenErrorResponse
		if decErr := json.NewDecoder(resp.Body).Decode(&errResp); decErr == nil {
			return "", &AuthError{
				Provider:    "oauth2",
				Message:     errResp.Description,
				Code:        errResp.Error,
				Recoverable: errResp.Error != "invalid_grant",
			}
		}
		return "", fmt.Errorf("token endpoint returned status %d", resp.StatusCode)
	}

	var tokenResp tokenResponse
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("decode token response: %w", err)
	}

	m.accessToken = tokenResp.AccessToken
	m.expiry = time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second)

	// Handle token rotation: if we got a new refresh token, update it.
	if tokenResp.RefreshToken != "" {
		m.refreshToken = tokenResp.RefreshToken
	}

	m.logger.Debug().
		Time("expiry", m.expiry).
		Msg("OAuth2 token refreshed successfully")

	return m.accessToken, nil
}

// AuthError represents an authentication error with provider context.
type AuthError struct {
	Provider    string
	Message     string
	Code        string
	Recoverable bool
}

func (e *AuthError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("%s auth error (%s): %s", e.Provider, e.Code, e.Message)
	}
	return fmt.Sprintf("%s auth error: %s", e.Provider, e.Message)
}
