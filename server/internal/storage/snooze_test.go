package storage

import (
	"context"
	"testing"
	"time"
)

func TestIntegrationCreateAndGetSnooze(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	snoozeStore := NewSnoozeStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Snooze Test")

	returnAt := time.Now().Add(2 * time.Hour).UTC().Truncate(time.Microsecond)
	snz, err := snoozeStore.CreateSnooze(ctx, email.ID, returnAt, 1)
	if err != nil {
		t.Fatalf("CreateSnooze() error: %v", err)
	}

	if snz.ID == "" {
		t.Error("expected generated snooze ID")
	}
	if snz.EmailID != email.ID {
		t.Errorf("expected email_id %s, got %s", email.ID, snz.EmailID)
	}
	if !snz.IsActive {
		t.Error("expected is_active=true")
	}
	if snz.SnoozeCount != 1 {
		t.Errorf("expected snooze_count=1, got %d", snz.SnoozeCount)
	}

	// Get active snooze
	active, err := snoozeStore.GetActiveSnooze(ctx, email.ID)
	if err != nil {
		t.Fatalf("GetActiveSnooze() error: %v", err)
	}
	if active.ID != snz.ID {
		t.Errorf("expected snooze ID %s, got %s", snz.ID, active.ID)
	}
}

func TestIntegrationDeactivateSnooze(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	snoozeStore := NewSnoozeStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Deactivate Snooze Test")

	returnAt := time.Now().Add(2 * time.Hour).UTC().Truncate(time.Microsecond)
	if _, err := snoozeStore.CreateSnooze(ctx, email.ID, returnAt, 1); err != nil {
		t.Fatalf("CreateSnooze() error: %v", err)
	}

	if err := snoozeStore.DeactivateSnooze(ctx, email.ID); err != nil {
		t.Fatalf("DeactivateSnooze() error: %v", err)
	}

	// GetActiveSnooze should now fail
	_, err := snoozeStore.GetActiveSnooze(ctx, email.ID)
	if err == nil {
		t.Error("expected error after deactivation")
	}
}

func TestIntegrationDeactivateSnoozeNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	snoozeStore := NewSnoozeStore(pool)

	err := snoozeStore.DeactivateSnooze(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Error("expected error for non-existent snooze")
	}
}

func TestIntegrationGetExpiredSnoozes(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	snoozeStore := NewSnoozeStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)

	// Create emails with different snooze times
	email1 := createTestEmail(t, ctx, emailStore, accountID, "Expired Snooze 1")
	pastReturn := time.Now().Add(-1 * time.Hour).UTC().Truncate(time.Microsecond)
	if _, err := snoozeStore.CreateSnooze(ctx, email1.ID, pastReturn, 1); err != nil {
		t.Fatalf("CreateSnooze 1: %v", err)
	}

	email2 := createTestEmail(t, ctx, emailStore, accountID, "Future Snooze")
	futureReturn := time.Now().Add(24 * time.Hour).UTC().Truncate(time.Microsecond)
	if _, err := snoozeStore.CreateSnooze(ctx, email2.ID, futureReturn, 1); err != nil {
		t.Fatalf("CreateSnooze 2: %v", err)
	}

	expired, err := snoozeStore.GetExpiredSnoozes(ctx, time.Now())
	if err != nil {
		t.Fatalf("GetExpiredSnoozes() error: %v", err)
	}

	if len(expired) != 1 {
		t.Errorf("expected 1 expired snooze, got %d", len(expired))
	}
	if len(expired) > 0 && expired[0].EmailID != email1.ID {
		t.Errorf("expected expired snooze for email %s, got %s", email1.ID, expired[0].EmailID)
	}
}

func TestIntegrationGetExpiredSnoozesEmpty(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	snoozeStore := NewSnoozeStore(pool)

	// No snoozes exist, should return empty (not error)
	expired, err := snoozeStore.GetExpiredSnoozes(ctx, time.Now().Add(-365*24*time.Hour))
	if err != nil {
		t.Fatalf("GetExpiredSnoozes() error: %v", err)
	}
	if len(expired) != 0 {
		t.Errorf("expected empty result, got %d", len(expired))
	}
}

func TestIntegrationUpdateSnooze(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	snoozeStore := NewSnoozeStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Update Snooze Test")

	returnAt := time.Now().Add(2 * time.Hour).UTC().Truncate(time.Microsecond)
	snz, err := snoozeStore.CreateSnooze(ctx, email.ID, returnAt, 1)
	if err != nil {
		t.Fatalf("CreateSnooze() error: %v", err)
	}

	newReturn := time.Now().Add(48 * time.Hour).UTC().Truncate(time.Microsecond)
	if err := snoozeStore.UpdateSnooze(ctx, snz.ID, newReturn, 2); err != nil {
		t.Fatalf("UpdateSnooze() error: %v", err)
	}

	updated, err := snoozeStore.GetActiveSnooze(ctx, email.ID)
	if err != nil {
		t.Fatalf("GetActiveSnooze() error: %v", err)
	}
	if updated.SnoozeCount != 2 {
		t.Errorf("expected snooze_count=2, got %d", updated.SnoozeCount)
	}
}
