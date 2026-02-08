package jobs

import (
	"context"
	"fmt"
	"testing"
	"time"
)

// mockStore implements FilteredCleanupStore for testing.
type mockStore struct {
	deleteFn func(ctx context.Context, cutoff time.Time) ([]string, error)
}

func (m *mockStore) DeleteFilteredEmailsBefore(ctx context.Context, cutoff time.Time) ([]string, error) {
	return m.deleteFn(ctx, cutoff)
}

// mockBroadcaster records broadcast calls.
type mockBroadcaster struct {
	events []broadcastCall
}

type broadcastCall struct {
	eventType string
	payload   any
}

func (m *mockBroadcaster) BroadcastEvent(eventType string, payload any) {
	m.events = append(m.events, broadcastCall{eventType: eventType, payload: payload})
}

func TestCutoffTime(t *testing.T) {
	tests := []struct {
		name          string
		retentionDays int
	}{
		{"default 14 days", 14},
		{"1 day", 1},
		{"30 days", 30},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			before := time.Now().UTC().AddDate(0, 0, -tt.retentionDays)
			cutoff := CutoffTime(tt.retentionDays)
			after := time.Now().UTC().AddDate(0, 0, -tt.retentionDays)

			if cutoff.Before(before) || cutoff.After(after) {
				t.Errorf("cutoff %v not between %v and %v", cutoff, before, after)
			}
		})
	}
}

func TestRunFilteredCleanupOnce_DeletesAndBroadcasts(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, cutoff time.Time) ([]string, error) {
			// Verify cutoff is approximately 14 days ago.
			expected := time.Now().UTC().AddDate(0, 0, -14)
			diff := cutoff.Sub(expected).Abs()
			if diff > time.Second {
				t.Errorf("cutoff diff from expected: %v", diff)
			}
			return []string{"id-1", "id-2", "id-3"}, nil
		},
	}
	broadcaster := &mockBroadcaster{}

	RunFilteredCleanupOnce(context.Background(), 14, store, broadcaster)

	if len(broadcaster.events) != 3 {
		t.Fatalf("expected 3 broadcast events, got %d", len(broadcaster.events))
	}
	for i, evt := range broadcaster.events {
		if evt.eventType != "email.deleted" {
			t.Errorf("event %d: got type %q, want %q", i, evt.eventType, "email.deleted")
		}
		payload, ok := evt.payload.(map[string]string)
		if !ok {
			t.Fatalf("event %d: payload type %T", i, evt.payload)
		}
		expectedID := fmt.Sprintf("id-%d", i+1)
		if payload["id"] != expectedID {
			t.Errorf("event %d: got id %q, want %q", i, payload["id"], expectedID)
		}
	}
}

func TestRunFilteredCleanupOnce_NoEmails(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, _ time.Time) ([]string, error) {
			return nil, nil
		},
	}
	broadcaster := &mockBroadcaster{}

	RunFilteredCleanupOnce(context.Background(), 14, store, broadcaster)

	if len(broadcaster.events) != 0 {
		t.Errorf("expected 0 broadcast events, got %d", len(broadcaster.events))
	}
}

func TestRunFilteredCleanupOnce_StoreError(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, _ time.Time) ([]string, error) {
			return nil, fmt.Errorf("db connection lost")
		},
	}
	broadcaster := &mockBroadcaster{}

	// Should not panic; error is logged.
	RunFilteredCleanupOnce(context.Background(), 14, store, broadcaster)

	if len(broadcaster.events) != 0 {
		t.Errorf("expected 0 broadcast events on error, got %d", len(broadcaster.events))
	}
}

func TestRunFilteredCleanupOnce_NilBroadcaster(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, _ time.Time) ([]string, error) {
			return []string{"id-1"}, nil
		},
	}

	// Should not panic with nil broadcaster.
	RunFilteredCleanupOnce(context.Background(), 14, store, nil)
}

func TestRunFilteredCleanup_StopsOnCancel(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, _ time.Time) ([]string, error) {
			return nil, nil
		},
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})

	go func() {
		RunFilteredCleanup(ctx, FilteredCleanupConfig{
			RetentionDays: 14,
			Interval:      time.Hour, // Won't fire; we cancel immediately.
		}, store, nil)
		close(done)
	}()

	cancel()

	select {
	case <-done:
		// Good, it stopped.
	case <-time.After(2 * time.Second):
		t.Fatal("RunFilteredCleanup did not stop after context cancellation")
	}
}

func TestRunFilteredCleanup_DefaultsApplied(t *testing.T) {
	store := &mockStore{
		deleteFn: func(_ context.Context, cutoff time.Time) ([]string, error) {
			expected := time.Now().UTC().AddDate(0, 0, -14)
			diff := cutoff.Sub(expected).Abs()
			if diff > time.Second {
				t.Errorf("expected default 14 day retention, cutoff diff: %v", diff)
			}
			return nil, nil
		},
	}

	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})

	go func() {
		RunFilteredCleanup(ctx, FilteredCleanupConfig{
			// Zero values: should default to 14 days and 1 hour.
			Interval: 50 * time.Millisecond, // Use short interval so ticker fires.
		}, store, nil)
		close(done)
	}()

	// Wait for at least one tick.
	time.Sleep(100 * time.Millisecond)
	cancel()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("RunFilteredCleanup did not stop")
	}
}
