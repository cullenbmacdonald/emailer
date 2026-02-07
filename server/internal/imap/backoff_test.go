package imap

import (
	"testing"
	"time"
)

func TestBackoff_ExponentialGrowth(t *testing.T) {
	b := NewBackoff(1*time.Second, 5*time.Minute)

	// Collect several durations and verify exponential growth.
	// Note: jitter means we can't check exact values, but we can check bounds.
	for i := 0; i < 5; i++ {
		d := b.Next()
		base := time.Duration(1<<i) * time.Second
		minExpected := time.Duration(float64(base) * 0.75) // base - 25% jitter
		maxExpected := time.Duration(float64(base) * 1.25) // base + 25% jitter

		if maxExpected > 5*time.Minute {
			maxExpected = time.Duration(float64(5*time.Minute) * 1.25)
		}

		if d < minExpected || d > maxExpected {
			t.Errorf("attempt %d: got %v, expected between %v and %v", i, d, minExpected, maxExpected)
		}
	}
}

func TestBackoff_CapsAtMax(t *testing.T) {
	b := NewBackoff(1*time.Second, 10*time.Second)

	// Drive past the cap.
	for i := 0; i < 20; i++ {
		b.Next()
	}

	// After many attempts, the base should be capped at max.
	d := b.Next()
	// With 25% jitter on a max of 10s, we expect between 7.5s and 12.5s.
	if d < 7500*time.Millisecond || d > 12500*time.Millisecond {
		t.Errorf("expected capped duration around 10s, got %v", d)
	}
}

func TestBackoff_Reset(t *testing.T) {
	b := NewBackoff(1*time.Second, 5*time.Minute)

	// Advance several attempts.
	for i := 0; i < 5; i++ {
		b.Next()
	}

	if b.Attempt() != 5 {
		t.Fatalf("expected attempt 5, got %d", b.Attempt())
	}

	b.Reset()

	if b.Attempt() != 0 {
		t.Fatalf("expected attempt 0 after reset, got %d", b.Attempt())
	}

	// First call after reset should be ~1s (base value).
	d := b.Next()
	if d < 750*time.Millisecond || d > 1250*time.Millisecond {
		t.Errorf("expected ~1s after reset, got %v", d)
	}
}

func TestBackoff_Attempt(t *testing.T) {
	b := NewBackoff(100*time.Millisecond, 1*time.Second)

	if b.Attempt() != 0 {
		t.Fatalf("expected initial attempt 0, got %d", b.Attempt())
	}

	b.Next()
	if b.Attempt() != 1 {
		t.Fatalf("expected attempt 1, got %d", b.Attempt())
	}

	b.Next()
	b.Next()
	if b.Attempt() != 3 {
		t.Fatalf("expected attempt 3, got %d", b.Attempt())
	}
}

func TestBackoff_ConcurrentSafe(t *testing.T) {
	b := NewBackoff(1*time.Millisecond, 100*time.Millisecond)
	done := make(chan struct{})

	for i := 0; i < 10; i++ {
		go func() {
			for j := 0; j < 100; j++ {
				b.Next()
				b.Attempt()
			}
			done <- struct{}{}
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}

	// Just verify it doesn't panic or deadlock.
	b.Reset()
}
