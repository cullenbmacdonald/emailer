package storage

import (
	"context"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
)

func TestIntegrationSaveAndGetClassification(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	classStore := NewClassificationStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Classify Test")

	c := &models.Classification{
		Classification: models.ClassActionRequired,
		Confidence:     0.95,
		ClassifiedBy:   models.ClassifiedByRules,
		Reason:         "VIP sender",
	}

	if err := classStore.SaveClassification(ctx, email.ID, c); err != nil {
		t.Fatalf("SaveClassification() error: %v", err)
	}

	got, err := classStore.GetClassification(ctx, email.ID)
	if err != nil {
		t.Fatalf("GetClassification() error: %v", err)
	}

	if got.Classification != models.ClassActionRequired {
		t.Errorf("expected classification action_required, got %s", got.Classification)
	}
	if got.Confidence != 0.95 {
		t.Errorf("expected confidence 0.95, got %f", got.Confidence)
	}
	if got.ClassifiedBy != models.ClassifiedByRules {
		t.Errorf("expected classified_by rules, got %s", got.ClassifiedBy)
	}
	if got.Reason != "VIP sender" {
		t.Errorf("expected reason 'VIP sender', got %s", got.Reason)
	}
}

func TestIntegrationSaveClassificationUpsert(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	classStore := NewClassificationStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Upsert Test")

	// Save initial classification
	c1 := &models.Classification{
		Classification: models.ClassNewsletter,
		Confidence:     0.80,
		ClassifiedBy:   models.ClassifiedByFeatures,
	}
	if err := classStore.SaveClassification(ctx, email.ID, c1); err != nil {
		t.Fatalf("first SaveClassification() error: %v", err)
	}

	// Upsert with different values
	c2 := &models.Classification{
		Classification: models.ClassActionRequired,
		Confidence:     0.99,
		ClassifiedBy:   models.ClassifiedByUser,
		Reason:         "User override",
	}
	if err := classStore.SaveClassification(ctx, email.ID, c2); err != nil {
		t.Fatalf("second SaveClassification() error: %v", err)
	}

	got, err := classStore.GetClassification(ctx, email.ID)
	if err != nil {
		t.Fatalf("GetClassification() error: %v", err)
	}

	if got.Classification != models.ClassActionRequired {
		t.Errorf("expected upserted classification, got %s", got.Classification)
	}
	if got.Confidence != 0.99 {
		t.Errorf("expected upserted confidence, got %f", got.Confidence)
	}
}

func TestIntegrationGetClassificationNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	classStore := NewClassificationStore(pool)

	_, err := classStore.GetClassification(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Fatal("expected error for non-existent classification")
	}
}

func TestIntegrationUpdateClassification(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	classStore := NewClassificationStore(pool)
	t.Cleanup(func() { cleanupAllTestData(t, emailStore) })

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Update Class Test")

	initial := &models.Classification{
		Classification: models.ClassFiltered,
		Confidence:     0.70,
		ClassifiedBy:   models.ClassifiedByFeatures,
	}
	if err := classStore.SaveClassification(ctx, email.ID, initial); err != nil {
		t.Fatalf("SaveClassification() error: %v", err)
	}

	updated := &models.Classification{
		Classification: models.ClassActionRequired,
		Confidence:     1.0,
		ClassifiedBy:   models.ClassifiedByUser,
		Reason:         "Manually reclassified",
		IsOverridden:   true,
	}
	if err := classStore.UpdateClassification(ctx, email.ID, updated); err != nil {
		t.Fatalf("UpdateClassification() error: %v", err)
	}

	got, err := classStore.GetClassification(ctx, email.ID)
	if err != nil {
		t.Fatalf("GetClassification() error: %v", err)
	}

	if !got.IsOverridden {
		t.Error("expected is_overridden=true")
	}
	if got.Classification != models.ClassActionRequired {
		t.Errorf("expected classification action_required, got %s", got.Classification)
	}
}

func TestIntegrationUpdateClassificationNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	classStore := NewClassificationStore(pool)

	err := classStore.UpdateClassification(ctx, "00000000-0000-0000-0000-000000000000", &models.Classification{
		Classification: models.ClassActionRequired,
		Confidence:     1.0,
		ClassifiedBy:   models.ClassifiedByUser,
	})
	if err == nil {
		t.Fatal("expected error for non-existent classification")
	}
}

func TestIntegrationRecordTrainingSignal(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	emailStore := NewEmailStore(pool)
	classStore := NewClassificationStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM classification_training")
		cleanupAllTestData(t, emailStore)
	})

	accountID := setupTestData(t, ctx, emailStore)
	email := createTestEmail(t, ctx, emailStore, accountID, "Training Test")

	err := classStore.RecordTrainingSignal(ctx, email.ID, models.ClassFiltered, models.ClassActionRequired, false)
	if err != nil {
		t.Fatalf("RecordTrainingSignal() error: %v", err)
	}

	// Verify it was recorded
	var count int
	qErr := pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM classification_training WHERE email_id = $1",
		email.ID,
	).Scan(&count)
	if qErr != nil {
		t.Fatalf("query training signals: %v", qErr)
	}
	if count != 1 {
		t.Errorf("expected 1 training signal, got %d", count)
	}
}

// Verify pgx.ErrNoRows is used correctly
func TestPgxErrNoRowsIsUsed(t *testing.T) {
	// Just a compile-time check that we import pgx correctly
	_ = pgx.ErrNoRows
}
