package classifier

import (
	"context"
	"strings"
	"sync"
	"time"

	"github.com/rs/zerolog"
)

// VIPListProvider loads VIP senders from storage.
type VIPListProvider interface {
	ListVIPEmails(ctx context.Context) ([]string, error)
}

// VIPCache implements VIPChecker with an in-memory cache backed by the database.
// It supports both exact email matches and domain matches (entries starting with @).
type VIPCache struct {
	provider VIPListProvider
	logger   zerolog.Logger

	mu      sync.RWMutex
	emails  map[string]bool // exact email -> true (lowercased)
	domains map[string]bool // domain (without @) -> true (lowercased)

	refreshInterval time.Duration
	stopCh          chan struct{}
}

// NewVIPCache creates a VIP cache that loads from the given provider.
// It performs an initial load and starts a background refresh goroutine.
func NewVIPCache(provider VIPListProvider, refreshInterval time.Duration, logger zerolog.Logger) *VIPCache {
	if refreshInterval <= 0 {
		refreshInterval = 5 * time.Minute
	}
	c := &VIPCache{
		provider:        provider,
		logger:          logger.With().Str("component", "vip-cache").Logger(),
		emails:          make(map[string]bool),
		domains:         make(map[string]bool),
		refreshInterval: refreshInterval,
		stopCh:          make(chan struct{}),
	}
	return c
}

// Start performs an initial load and begins periodic refresh.
func (c *VIPCache) Start(ctx context.Context) {
	if err := c.Refresh(ctx); err != nil {
		c.logger.Warn().Err(err).Msg("initial VIP cache load failed")
	}
	go c.refreshLoop(ctx)
}

// Stop stops the background refresh goroutine.
func (c *VIPCache) Stop() {
	close(c.stopCh)
}

// IsVIP checks if an email matches a VIP sender (exact or domain match).
func (c *VIPCache) IsVIP(_ context.Context, email string) (bool, error) {
	lower := strings.ToLower(email)

	c.mu.RLock()
	defer c.mu.RUnlock()

	// Exact match
	if c.emails[lower] {
		return true, nil
	}

	// Domain match
	if atIdx := strings.LastIndex(lower, "@"); atIdx >= 0 {
		domain := lower[atIdx+1:]
		if c.domains[domain] {
			return true, nil
		}
	}

	return false, nil
}

// Refresh reloads the VIP list from the provider.
func (c *VIPCache) Refresh(ctx context.Context) error {
	entries, err := c.provider.ListVIPEmails(ctx)
	if err != nil {
		return err
	}

	emails := make(map[string]bool, len(entries))
	domains := make(map[string]bool)

	for _, entry := range entries {
		lower := strings.ToLower(entry)
		if strings.HasPrefix(lower, "@") {
			// Domain entry: @company.com
			domains[lower[1:]] = true
		} else {
			emails[lower] = true
		}
	}

	c.mu.Lock()
	c.emails = emails
	c.domains = domains
	c.mu.Unlock()

	c.logger.Debug().Int("emails", len(emails)).Int("domains", len(domains)).Msg("VIP cache refreshed")
	return nil
}

func (c *VIPCache) refreshLoop(ctx context.Context) {
	ticker := time.NewTicker(c.refreshInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-c.stopCh:
			return
		case <-ticker.C:
			if err := c.Refresh(ctx); err != nil {
				c.logger.Warn().Err(err).Msg("VIP cache refresh failed")
			}
		}
	}
}
