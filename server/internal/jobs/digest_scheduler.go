// Package jobs implements background workers and scheduled tasks.
package jobs

import (
	"context"

	"github.com/cullenbmacdonald/emailer/internal/digest"
)

// StartDigestScheduler starts the digest scheduler as a background goroutine.
// It returns immediately. The goroutine will run until ctx is cancelled.
func StartDigestScheduler(ctx context.Context, scheduler *digest.Scheduler) {
	go scheduler.Run(ctx)
}
