package imap

import (
	"context"
	"fmt"
	"sync"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

// Manager coordinates IMAP connections for all configured email accounts.
// It starts IDLE + worker goroutines per account and exposes a unified
// NewEmails channel for the processing pipeline.
type Manager struct {
	accounts  map[string]*Account // keyed by account ID
	newEmails chan *FetchedEmail

	// onStatusChange is called when any account's status changes.
	onStatusChange StatusChangeFunc

	cancel context.CancelFunc
	wg     sync.WaitGroup

	logger zerolog.Logger
}

// NewManager creates a new IMAP manager from configuration.
func NewManager(accounts []config.AccountConfig, logger zerolog.Logger) (*Manager, error) {
	mgr := &Manager{
		accounts:  make(map[string]*Account, len(accounts)),
		newEmails: make(chan *FetchedEmail, 100),
		logger:    logger.With().Str("component", "imap-manager").Logger(),
	}

	for _, acctCfg := range accounts {
		acct, err := NewAccount(acctCfg, logger)
		if err != nil {
			// Close any already-created accounts.
			for _, a := range mgr.accounts {
				a.Close()
			}
			return nil, fmt.Errorf("create account %s: %w", acctCfg.Name, err)
		}
		mgr.accounts[acctCfg.ID] = acct
	}

	return mgr, nil
}

// SetStatusChangeCallback sets the callback for account status changes.
// Must be called before Start.
func (m *Manager) SetStatusChangeCallback(fn StatusChangeFunc) {
	m.onStatusChange = fn
	for _, acct := range m.accounts {
		acct.SetStatusChangeCallback(fn)
	}
}

// SetSyncer configures the email sync pipeline for all accounts.
// Must be called before Start.
func (m *Manager) SetSyncer(syncer *EmailSyncer) {
	for _, acct := range m.accounts {
		acct.syncer = syncer
	}
}

// Start starts IDLE and worker goroutines for each configured account.
// It returns immediately; goroutines run in the background.
func (m *Manager) Start(ctx context.Context) {
	ctx, m.cancel = context.WithCancel(ctx)

	for id, acct := range m.accounts {
		m.logger.Info().Str("account_id", id).Str("email", acct.Config().Email).Msg("starting IMAP account")

		// Start IDLE goroutine.
		m.wg.Add(1)
		go func(a *Account) {
			defer m.wg.Done()
			a.RunIDLE(ctx)
		}(acct)

		// Start worker goroutine.
		m.wg.Add(1)
		go func(a *Account) {
			defer m.wg.Done()
			a.RunWorker(ctx, m.newEmails)
		}(acct)
	}

	m.logger.Info().Int("account_count", len(m.accounts)).Msg("IMAP manager started")
}

// Stop gracefully shuts down all goroutines and closes connections.
func (m *Manager) Stop() {
	if m.cancel != nil {
		m.cancel()
	}
	m.wg.Wait()

	for _, acct := range m.accounts {
		acct.Close()
	}

	m.logger.Info().Msg("IMAP manager stopped")
}

// NewEmails returns a channel that receives notifications of newly fetched emails.
func (m *Manager) NewEmails() <-chan *FetchedEmail {
	return m.newEmails
}

// AccountStatuses returns the current connection status for each account.
func (m *Manager) AccountStatuses() map[string]models.Account {
	statuses := make(map[string]models.Account, len(m.accounts))
	for id, acct := range m.accounts {
		status, message := acct.Status()
		cfg := acct.Config()
		statuses[id] = models.Account{
			ID:            cfg.ID,
			Name:          cfg.Name,
			EmailAddress:  cfg.Email,
			AccountType:   cfg.AccountType,
			Color:         cfg.Color,
			Status:        status,
			StatusMessage: message,
		}
	}
	return statuses
}

// Account returns a specific account by ID (for direct access by sync pipeline).
func (m *Manager) Account(id string) (*Account, bool) {
	acct, ok := m.accounts[id]
	return acct, ok
}

// AccountCount returns the number of configured accounts.
func (m *Manager) AccountCount() int {
	return len(m.accounts)
}
