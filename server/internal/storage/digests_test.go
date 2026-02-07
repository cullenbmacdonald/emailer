package storage

import (
	"context"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestIntegrationSaveAndGetDigest(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM digests")
	})

	count := 5
	digest := &models.DailyDigest{
		DigestType: models.DigestTypeMorning,
		Sections: []models.DigestSection{
			{
				Type:  "action_queue_summary",
				Title: "Action Items",
				Count: &count,
			},
		},
	}

	saved, err := store.SaveDigest(ctx, digest)
	if err != nil {
		t.Fatalf("SaveDigest() error: %v", err)
	}
	if saved.ID == "" {
		t.Error("expected generated ID")
	}

	got, err := store.GetDigest(ctx, saved.ID)
	if err != nil {
		t.Fatalf("GetDigest() error: %v", err)
	}
	if got.DigestType != models.DigestTypeMorning {
		t.Errorf("expected type morning, got %s", got.DigestType)
	}
	if len(got.Sections) != 1 {
		t.Fatalf("expected 1 section, got %d", len(got.Sections))
	}
	if got.Sections[0].Type != "action_queue_summary" {
		t.Errorf("expected section type action_queue_summary, got %s", got.Sections[0].Type)
	}
	if got.Sections[0].Count == nil || *got.Sections[0].Count != 5 {
		t.Error("expected section count=5")
	}
}

func TestIntegrationGetLatestDigest(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM digests")
	})

	// Save morning and evening digests
	morning := &models.DailyDigest{
		DigestType: models.DigestTypeMorning,
		Sections:   []models.DigestSection{{Type: "morning_section", Title: "Morning"}},
	}
	if _, err := store.SaveDigest(ctx, morning); err != nil {
		t.Fatalf("SaveDigest morning: %v", err)
	}

	evening := &models.DailyDigest{
		DigestType: models.DigestTypeEvening,
		Sections:   []models.DigestSection{{Type: "evening_section", Title: "Evening"}},
	}
	if _, err := store.SaveDigest(ctx, evening); err != nil {
		t.Fatalf("SaveDigest evening: %v", err)
	}

	// Get latest morning
	latest, err := store.GetLatestDigest(ctx, models.DigestTypeMorning)
	if err != nil {
		t.Fatalf("GetLatestDigest(morning) error: %v", err)
	}
	if latest.DigestType != models.DigestTypeMorning {
		t.Errorf("expected morning digest, got %s", latest.DigestType)
	}

	// Get latest regardless of type
	latestAny, err := store.GetLatestDigest(ctx, "")
	if err != nil {
		t.Fatalf("GetLatestDigest('') error: %v", err)
	}
	// Should be the evening since it was saved second
	if latestAny.DigestType != models.DigestTypeEvening {
		t.Errorf("expected evening digest (most recent), got %s", latestAny.DigestType)
	}
}

func TestIntegrationGetDigestNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)

	_, err := store.GetDigest(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Fatal("expected error for non-existent digest")
	}
}

func TestIntegrationListDigests(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM digests")
	})

	for i := 0; i < 5; i++ {
		d := &models.DailyDigest{
			DigestType: models.DigestTypeMorning,
			Sections:   []models.DigestSection{{Type: "test", Title: "Test"}},
		}
		if _, err := store.SaveDigest(ctx, d); err != nil {
			t.Fatalf("SaveDigest: %v", err)
		}
	}

	page1, err := store.ListDigests(ctx, "", 2)
	if err != nil {
		t.Fatalf("ListDigests page 1 error: %v", err)
	}
	if len(page1.Data) != 2 {
		t.Fatalf("expected 2 on page 1, got %d", len(page1.Data))
	}
	if !page1.HasMore {
		t.Error("expected HasMore=true")
	}

	page2, err := store.ListDigests(ctx, page1.NextCursor, 2)
	if err != nil {
		t.Fatalf("ListDigests page 2 error: %v", err)
	}
	if len(page2.Data) != 2 {
		t.Fatalf("expected 2 on page 2, got %d", len(page2.Data))
	}

	// No overlap
	if page1.Data[0].ID == page2.Data[0].ID {
		t.Error("pages overlap")
	}
}

func TestIntegrationUpdateDigest(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM digests")
	})

	d := &models.DailyDigest{
		DigestType: models.DigestTypeMorning,
		Sections:   []models.DigestSection{{Type: "test", Title: "Test"}},
	}
	saved, err := store.SaveDigest(ctx, d)
	if err != nil {
		t.Fatalf("SaveDigest: %v", err)
	}

	isRead := true
	if err := store.UpdateDigest(ctx, saved.ID, models.DigestUpdateRequest{IsRead: &isRead}); err != nil {
		t.Fatalf("UpdateDigest() error: %v", err)
	}

	got, err := store.GetDigest(ctx, saved.ID)
	if err != nil {
		t.Fatalf("GetDigest: %v", err)
	}
	if !got.IsRead {
		t.Error("expected is_read=true after update")
	}
}

func TestIntegrationUpdateDigestNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)

	isRead := true
	err := store.UpdateDigest(ctx, "00000000-0000-0000-0000-000000000000", models.DigestUpdateRequest{IsRead: &isRead})
	if err == nil {
		t.Fatal("expected error for non-existent digest")
	}
}

func TestIntegrationListDigestsEmpty(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewDigestStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM digests")
	})

	resp, err := store.ListDigests(ctx, "", 10)
	if err != nil {
		t.Fatalf("ListDigests() error: %v", err)
	}
	if resp.Data == nil {
		t.Error("expected non-nil Data slice")
	}
	if len(resp.Data) != 0 {
		t.Errorf("expected 0 digests, got %d", len(resp.Data))
	}
}
