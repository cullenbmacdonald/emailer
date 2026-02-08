// Package jobs implements background tasks for the email server.
package jobs

import (
	"context"
	"time"

	"github.com/rs/zerolog/log"
)

// FilteredCleanupStore is the interface required by the filtered cleanup job.
type FilteredCleanupStore interface {
	DeleteFilteredEmailsBefore(ctx context.Context, cutoff time.Time) ([]string, error)
}

// Broadcaster is the interface for sending WebSocket events.
type Broadcaster interface {
	BroadcastEvent(eventType string, payload any)
}

// FilteredCleanupConfig holds configuration for the filtered cleanup job.
type FilteredCleanupConfig struct {
	RetentionDays int
	Interval      time.Duration
}

// RunFilteredCleanup starts the hourly filtered email cleanup job.
// It blocks until the context is cancelled.
func RunFilteredCleanup(ctx context.Context, cfg FilteredCleanupConfig, store FilteredCleanupStore, broadcaster Broadcaster) {
	if cfg.RetentionDays < 1 {
		cfg.RetentionDays = 14
	}
	if cfg.Interval == 0 {
		cfg.Interval = time.Hour
	}

	ticker := time.NewTicker(cfg.Interval)
	defer ticker.Stop()

	log.Info().
		Int("retention_days", cfg.RetentionDays).
		Dur("interval", cfg.Interval).
		Msg("filtered cleanup job started")

	for {
		select {
		case <-ctx.Done():
			log.Info().Msg("filtered cleanup job stopped")
			return
		case <-ticker.C:
			runFilteredCleanup(ctx, cfg.RetentionDays, store, broadcaster)
		}
	}
}

// RunFilteredCleanupOnce executes a single cleanup pass. Exported for testing.
func RunFilteredCleanupOnce(ctx context.Context, retentionDays int, store FilteredCleanupStore, broadcaster Broadcaster) {
	runFilteredCleanup(ctx, retentionDays, store, broadcaster)
}

// CutoffTime calculates the cutoff time for a given retention period.
// Exported for testing.
func CutoffTime(retentionDays int) time.Time {
	return time.Now().UTC().AddDate(0, 0, -retentionDays)
}

func runFilteredCleanup(ctx context.Context, retentionDays int, store FilteredCleanupStore, broadcaster Broadcaster) {
	cutoff := CutoffTime(retentionDays)

	ids, err := store.DeleteFilteredEmailsBefore(ctx, cutoff)
	if err != nil {
		log.Error().Err(err).Msg("filtered cleanup: failed to delete emails")
		return
	}

	if len(ids) == 0 {
		log.Debug().Msg("filtered cleanup: no emails to delete")
		return
	}

	log.Info().
		Int("count", len(ids)).
		Time("cutoff", cutoff).
		Msg("filtered cleanup: deleted emails")

	if broadcaster != nil {
		for _, id := range ids {
			broadcaster.BroadcastEvent("email.deleted", map[string]string{"id": id})
		}
	}
}
