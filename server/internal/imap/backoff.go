package imap

import (
	"math"
	"math/rand/v2"
	"sync"
	"time"
)

// Backoff implements exponential backoff with jitter for reconnection logic.
type Backoff struct {
	mu      sync.Mutex
	attempt int
	min     time.Duration
	max     time.Duration
}

// NewBackoff creates a Backoff with the given min and max durations.
func NewBackoff(min, max time.Duration) *Backoff {
	return &Backoff{
		min: min,
		max: max,
	}
}

// Next returns the next backoff duration and increments the attempt counter.
// The duration is base * 2^attempt, capped at max, with ±25% jitter.
func (b *Backoff) Next() time.Duration {
	b.mu.Lock()
	defer b.mu.Unlock()

	d := float64(b.min) * math.Pow(2, float64(b.attempt))
	if d > float64(b.max) {
		d = float64(b.max)
	}
	b.attempt++

	// Add ±25% jitter to avoid thundering herd
	jitter := d * 0.25 * (rand.Float64()*2 - 1) //nolint:gosec // jitter does not need crypto rand
	d += jitter

	return time.Duration(d)
}

// Reset resets the attempt counter back to zero (call after a successful connection).
func (b *Backoff) Reset() {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.attempt = 0
}

// Attempt returns the current attempt number.
func (b *Backoff) Attempt() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.attempt
}
