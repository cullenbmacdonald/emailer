package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"

	"github.com/cullenbmacdonald/emailer/internal/auth"
	"github.com/cullenbmacdonald/emailer/internal/config"
)

const (
	oauthCallbackAddr = "localhost:8089"
	oauthRedirectURL  = "http://localhost:8089/callback"
)

// runTokenAuth performs the OAuth2 authorization flow for the given account ID.
func runTokenAuth(cfg *config.Config, accountID string) {
	var acct *config.AccountConfig
	for i := range cfg.Accounts {
		if cfg.Accounts[i].ID == accountID {
			acct = &cfg.Accounts[i]
			break
		}
	}
	if acct == nil {
		fmt.Fprintf(os.Stderr, "account %q not found in config\n", accountID)
		fmt.Fprintf(os.Stderr, "available accounts:\n")
		for _, a := range cfg.Accounts {
			fmt.Fprintf(os.Stderr, "  - %s (%s)\n", a.ID, a.Email)
		}
		os.Exit(1)
	}

	if acct.OAuth.ClientID == "" || acct.OAuth.ClientSecret == "" {
		fmt.Fprintf(os.Stderr, "account %q is missing oauth.client_id or oauth.client_secret\n", accountID)
		os.Exit(1)
	}

	if acct.OAuth.TokenFile == "" {
		fmt.Fprintf(os.Stderr, "account %q is missing oauth.token_file\n", accountID)
		os.Exit(1)
	}

	oauthCfg := &oauth2.Config{
		ClientID:     acct.OAuth.ClientID,
		ClientSecret: acct.OAuth.ClientSecret,
		Endpoint:     google.Endpoint,
		RedirectURL:  oauthRedirectURL,
		Scopes:       []string{"https://mail.google.com/"},
	}

	// Generate auth URL and open browser.
	authURL := oauthCfg.AuthCodeURL("state", oauth2.AccessTypeOffline, oauth2.ApprovalForce)
	fmt.Printf("Opening browser for OAuth2 consent...\n")
	fmt.Printf("If the browser doesn't open, visit:\n%s\n\n", authURL)

	// Best-effort browser open.
	_ = exec.Command("open", authURL).Start()

	// Start callback server.
	codeCh := make(chan string, 1)
	errCh := make(chan error, 1)

	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			errMsg := r.URL.Query().Get("error")
			if errMsg == "" {
				errMsg = "no code in callback"
			}
			_, _ = fmt.Fprintf(w, "Error: %s\n", errMsg)
			errCh <- fmt.Errorf("OAuth callback error: %s", errMsg)
			return
		}
		_, _ = fmt.Fprintf(w, "Authorization successful! You can close this tab.")
		codeCh <- code
	})

	srv := &http.Server{
		Addr:              oauthCallbackAddr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- fmt.Errorf("callback server: %w", err)
		}
	}()

	// Wait for code or error.
	var code string
	select {
	case code = <-codeCh:
	case err := <-errCh:
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	// Shut down the callback server.
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	_ = srv.Shutdown(shutCtx)
	cancel()

	// Exchange code for token.
	fmt.Printf("Exchanging authorization code for tokens...\n")
	token, err := oauthCfg.Exchange(context.Background(), code)
	if err != nil {
		fmt.Fprintf(os.Stderr, "token exchange failed: %v\n", err)
		os.Exit(1)
	}

	// Save token file.
	tf := &auth.TokenFile{
		AccessToken:  token.AccessToken,
		RefreshToken: token.RefreshToken,
		TokenType:    token.TokenType,
		Expiry:       token.Expiry,
	}

	if err := auth.SaveTokenFile(acct.OAuth.TokenFile, tf); err != nil {
		fmt.Fprintf(os.Stderr, "failed to save token: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Token saved to %s\n", acct.OAuth.TokenFile)
	fmt.Printf("Account: %s (%s)\n", acct.Name, acct.Email)
}
