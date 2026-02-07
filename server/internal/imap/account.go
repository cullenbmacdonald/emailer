package imap

import (
	"context"
	"errors"
	"fmt"
	"mime"
	"sync"
	"time"

	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/emersion/go-message/charset"
	"github.com/emersion/go-sasl"
	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

const defaultPoolSize = 3

// StatusChangeFunc is a callback invoked when an account's connection status changes.
type StatusChangeFunc func(accountID, status, message string)

// FetchedEmail represents a newly synced email ready for classification.
type FetchedEmail struct {
	AccountID    string
	AccountName  string
	AccountColor string
	Email        *models.Email // nil if syncer is not configured (placeholder mode).
}

// Account represents a single email account's IMAP connection management.
// It runs an IDLE goroutine for real-time notifications and maintains a
// connection pool for fetch operations.
type Account struct {
	mu sync.RWMutex

	cfg      config.AccountConfig
	provider *ProviderConfig

	// OAuth2 token manager (nil for app-password accounts).
	tokenMgr *OAuthTokenManager

	// Connection pool for worker operations.
	pool *ConnPool

	// Status tracking.
	status        string
	statusMessage string

	// Callback fired when status changes (set by Manager).
	onStatusChange StatusChangeFunc

	// Syncer for fetch-parse-store pipeline (set by Manager).
	syncer *EmailSyncer

	// Channel for signaling that new mail has been detected.
	newMailCh chan struct{}

	// Backoff for reconnection.
	backoff *Backoff

	logger zerolog.Logger
}

// NewAccount creates a new Account from configuration.
func NewAccount(acctCfg config.AccountConfig, logger zerolog.Logger) (*Account, error) {
	provCfg, err := DefaultProviderConfig(acctCfg.Provider)
	if err != nil {
		return nil, fmt.Errorf("provider config for %s: %w", acctCfg.Name, err)
	}

	// Auto-detect auth method: if app_password is set and no OAuth credentials
	// are configured, use plain auth even if the provider defaults to OAuth2.
	// This lets Gmail users skip OAuth by using an app password.
	if acctCfg.AppPassword != "" && acctCfg.OAuth.ClientID == "" && acctCfg.OAuth.ClientSecret == "" {
		provCfg.AuthMethod = AuthMethodPlain
	}

	// Override provider defaults with explicit config if provided.
	if acctCfg.IMAP.Host != "" {
		provCfg.IMAPHost = acctCfg.IMAP.Host
	}
	if acctCfg.IMAP.Port != 0 {
		provCfg.IMAPPort = acctCfg.IMAP.Port
	}

	acctLogger := logger.With().
		Str("account", acctCfg.Name).
		Str("email", acctCfg.Email).
		Logger()

	a := &Account{
		cfg:       acctCfg,
		provider:  provCfg,
		status:    models.AccountStatusOffline,
		newMailCh: make(chan struct{}, 1),
		backoff:   NewBackoff(1*time.Second, 5*time.Minute),
		logger:    acctLogger,
	}

	// Set up OAuth token manager for providers that need it.
	if provCfg.AuthMethod == AuthMethodXOAuth2 {
		tokenURL := GmailTokenURL
		if acctCfg.Provider == ProviderMicrosoft {
			tokenURL = MicrosoftTokenURL(acctCfg.OAuth.TenantID)
		}
		a.tokenMgr = NewOAuthTokenManager(OAuthManagerConfig{
			ClientID:     acctCfg.OAuth.ClientID,
			ClientSecret: acctCfg.OAuth.ClientSecret,
			RefreshToken: acctCfg.AppPassword, // Use app_password field for refresh token in dev
			TokenURL:     tokenURL,
		}, acctLogger)
	}

	// Create connection pool.
	a.pool = NewConnPool(defaultPoolSize, a.connect, acctLogger)

	return a, nil
}

// SetStatusChangeCallback sets the function called when account status changes.
func (a *Account) SetStatusChangeCallback(fn StatusChangeFunc) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.onStatusChange = fn
}

// connect creates a new authenticated IMAP connection.
func (a *Account) connect(ctx context.Context) (*imapclient.Client, error) {
	a.logger.Debug().Str("host", a.provider.IMAPAddress()).Msg("connecting to IMAP server")

	options := &imapclient.Options{
		WordDecoder: &mime.WordDecoder{CharsetReader: charset.Reader},
		UnilateralDataHandler: &imapclient.UnilateralDataHandler{
			Mailbox: func(data *imapclient.UnilateralDataMailbox) {
				if data.NumMessages != nil {
					a.logger.Debug().Uint32("num_messages", *data.NumMessages).Msg("mailbox update")
					a.signalNewMail()
				}
			},
		},
	}

	client, err := imapclient.DialTLS(a.provider.IMAPAddress(), options)
	if err != nil {
		return nil, fmt.Errorf("dial TLS %s: %w", a.provider.IMAPAddress(), err)
	}

	if err := client.WaitGreeting(); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("IMAP greeting: %w", err)
	}

	if err := a.authenticate(ctx, client); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("authenticate: %w", err)
	}

	a.logger.Debug().Msg("IMAP connection established and authenticated")
	return client, nil
}

// authenticate performs SASL authentication based on the provider type.
func (a *Account) authenticate(ctx context.Context, client *imapclient.Client) error {
	switch a.provider.AuthMethod {
	case AuthMethodXOAuth2:
		if a.tokenMgr == nil {
			return fmt.Errorf("OAuth2 token manager not configured for %s", a.cfg.Name)
		}
		token, err := a.tokenMgr.GetAccessToken(ctx)
		if err != nil {
			return fmt.Errorf("get access token: %w", err)
		}
		saslClient := NewXOAuth2Client(a.cfg.Email, token)
		return client.Authenticate(saslClient)
	case AuthMethodPlain:
		saslClient := sasl.NewPlainClient("", a.cfg.Email, a.cfg.AppPassword)
		return client.Authenticate(saslClient)
	default:
		return fmt.Errorf("unsupported auth method: %s", a.provider.AuthMethod)
	}
}

// signalNewMail non-blockingly sends a signal on the newMail channel.
func (a *Account) signalNewMail() {
	select {
	case a.newMailCh <- struct{}{}:
	default:
		// Already signaled, don't block.
	}
}

// RunIDLE runs the IDLE loop for the account. It reconnects with exponential
// backoff on failures. Authentication failures pause the account.
// This should be run as a goroutine.
func (a *Account) RunIDLE(ctx context.Context) {
	a.setStatus(models.AccountStatusSyncing, "connecting")

	for {
		select {
		case <-ctx.Done():
			a.setStatus(models.AccountStatusOffline, "shutdown")
			return
		default:
		}

		err := a.runIDLEOnce(ctx)
		if err == nil {
			continue
		}
		if ctx.Err() != nil {
			return
		}

		// Check if this is a non-recoverable auth error.
		var authErr *AuthError
		if errors.As(err, &authErr) && !authErr.Recoverable {
			a.logger.Error().Err(err).Msg("authentication failure, pausing account")
			a.setStatus(models.AccountStatusError, authErr.Message)
			// Wait for context cancellation (manual restart needed).
			<-ctx.Done()
			return
		}

		a.logger.Warn().Err(err).Msg("IDLE error, reconnecting with backoff")
		a.setStatus(models.AccountStatusOffline, err.Error())

		wait := a.backoff.Next()
		a.logger.Debug().Dur("backoff", wait).Int("attempt", a.backoff.Attempt()).Msg("waiting before reconnect")

		select {
		case <-ctx.Done():
			return
		case <-time.After(wait):
		}
	}
}

// runIDLEOnce connects, selects INBOX, and runs one IDLE session.
func (a *Account) runIDLEOnce(ctx context.Context) error {
	client, err := a.connect(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = client.Close() }()

	// SELECT INBOX for IDLE monitoring.
	if _, err := client.Select("INBOX", nil).Wait(); err != nil {
		return fmt.Errorf("select INBOX: %w", err)
	}

	a.backoff.Reset()
	a.setStatus(models.AccountStatusOnline, "")
	a.logger.Info().Msg("IDLE active on INBOX")

	// Trigger an initial fetch of existing messages.
	a.signalNewMail()

	return idleLoop(ctx, client, a.logger)
}

// RunWorker runs the worker loop that processes new mail signals.
// When signaled, it uses a pooled connection to fetch new messages.
// This should be run as a goroutine.
func (a *Account) RunWorker(ctx context.Context, newEmails chan<- *FetchedEmail) {
	for {
		select {
		case <-ctx.Done():
			return
		case <-a.newMailCh:
			a.fetchNewMessages(ctx, newEmails)
		}
	}
}

// fetchNewMessages fetches all new messages from INBOX using a pooled connection.
func (a *Account) fetchNewMessages(ctx context.Context, newEmails chan<- *FetchedEmail) {
	client, err := a.pool.Get(ctx)
	if err != nil {
		a.logger.Error().Err(err).Msg("failed to get pooled connection for fetch")
		return
	}
	defer a.pool.Put(client)

	// SELECT INBOX (needed for each pooled connection to fetch from the right mailbox).
	if _, err := client.Select("INBOX", nil).Wait(); err != nil {
		a.logger.Error().Err(err).Msg("failed to select INBOX for fetch")
		return
	}

	// If a syncer is configured, use the full sync pipeline.
	if a.syncer != nil {
		a.syncWithPipeline(ctx, client, newEmails)
		return
	}

	// Fallback: signal new mail without sync (pre-S-2.2 placeholder).
	select {
	case newEmails <- &FetchedEmail{
		AccountID:    a.cfg.ID,
		AccountName:  a.cfg.Name,
		AccountColor: a.cfg.Color,
	}:
	case <-ctx.Done():
	}
}

// syncWithPipeline runs the full fetch-parse-store sync for INBOX.
func (a *Account) syncWithPipeline(ctx context.Context, client *imapclient.Client, newEmails chan<- *FetchedEmail) {
	cfg := AccountFetchConfig{
		AccountID:    a.cfg.ID,
		AccountName:  a.cfg.Name,
		AccountColor: a.cfg.Color,
	}

	result, emails, err := a.syncer.SyncFolder(ctx, client, "INBOX", cfg, a.logger)
	if err != nil {
		a.logger.Error().Err(err).Msg("sync pipeline error")
	}

	if result != nil {
		a.logger.Info().
			Int("new", result.NewCount).
			Int("skipped", result.SkipCount).
			Int("errors", result.Errors).
			Msg("sync result")
	}

	// Emit each new email for downstream processing (classification).
	for _, email := range emails {
		select {
		case newEmails <- &FetchedEmail{
			AccountID:    a.cfg.ID,
			AccountName:  a.cfg.Name,
			AccountColor: a.cfg.Color,
			Email:        email,
		}:
		case <-ctx.Done():
			return
		}
	}
}

// Pool returns the connection pool for external use (e.g., by the sync pipeline).
func (a *Account) Pool() *ConnPool {
	return a.pool
}

// Status returns the current connection status of the account.
func (a *Account) Status() (string, string) {
	a.mu.RLock()
	defer a.mu.RUnlock()
	return a.status, a.statusMessage
}

// setStatus updates the account status and triggers the status change callback.
func (a *Account) setStatus(status, message string) {
	a.mu.Lock()
	changed := a.status != status || a.statusMessage != message
	a.status = status
	a.statusMessage = message
	cb := a.onStatusChange
	a.mu.Unlock()

	if changed {
		a.logger.Info().Str("status", status).Str("message", message).Msg("account status changed")
		if cb != nil {
			cb(a.cfg.ID, status, message)
		}
	}
}

// Config returns the account configuration.
func (a *Account) Config() config.AccountConfig {
	return a.cfg
}

// ProviderCfg returns the provider configuration.
func (a *Account) ProviderCfg() *ProviderConfig {
	return a.provider
}

// Close shuts down the connection pool.
func (a *Account) Close() {
	a.pool.Close()
}
