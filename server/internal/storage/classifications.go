package storage

import (
	"context"
	"fmt"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ClassificationStore provides CRUD operations for the classifications table.
type ClassificationStore struct {
	pool *pgxpool.Pool
}

// NewClassificationStore creates a new ClassificationStore.
func NewClassificationStore(pool *pgxpool.Pool) *ClassificationStore {
	return &ClassificationStore{pool: pool}
}

// SaveClassification inserts a new classification for an email.
func (s *ClassificationStore) SaveClassification(ctx context.Context, emailID string, c *models.Classification) error {
	query := `
		INSERT INTO classifications (email_id, classification, confidence, classified_by, reason)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (email_id) DO UPDATE SET
			classification = EXCLUDED.classification,
			confidence = EXCLUDED.confidence,
			classified_by = EXCLUDED.classified_by,
			reason = EXCLUDED.reason,
			updated_at = NOW()`

	_, err := s.pool.Exec(ctx, query,
		emailID, c.Classification, c.Confidence, c.ClassifiedBy, c.Reason,
	)
	if err != nil {
		return fmt.Errorf("save classification for email %s: %w", emailID, err)
	}
	return nil
}

// GetClassification returns the classification for an email.
func (s *ClassificationStore) GetClassification(ctx context.Context, emailID string) (*models.Classification, error) {
	query := `
		SELECT classification, confidence, classified_by, reason, is_overridden
		FROM classifications
		WHERE email_id = $1`

	var c models.Classification
	var reason *string
	err := s.pool.QueryRow(ctx, query, emailID).Scan(
		&c.Classification, &c.Confidence, &c.ClassifiedBy, &reason, &c.IsOverridden,
	)
	if err != nil {
		return nil, fmt.Errorf("get classification for email %s: %w", emailID, err)
	}
	if reason != nil {
		c.Reason = *reason
	}
	return &c, nil
}

// UpdateClassification updates an existing classification (e.g., for reclassify).
func (s *ClassificationStore) UpdateClassification(ctx context.Context, emailID string, c *models.Classification) error {
	query := `
		UPDATE classifications
		SET classification = $2, confidence = $3, classified_by = $4, reason = $5,
		    is_overridden = $6, updated_at = NOW()
		WHERE email_id = $1`

	tag, err := s.pool.Exec(ctx, query,
		emailID, c.Classification, c.Confidence, c.ClassifiedBy, c.Reason, c.IsOverridden,
	)
	if err != nil {
		return fmt.Errorf("update classification for email %s: %w", emailID, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// RecordTrainingSignal inserts a training signal into classification_training.
func (s *ClassificationStore) RecordTrainingSignal(ctx context.Context, emailID, previousClass, newClass string, isConfirm bool) error {
	query := `
		INSERT INTO classification_training (email_id, previous_classification, new_classification, is_confirm)
		VALUES ($1, $2, $3, $4)`

	_, err := s.pool.Exec(ctx, query, emailID, previousClass, newClass, isConfirm)
	if err != nil {
		return fmt.Errorf("record training signal for email %s: %w", emailID, err)
	}
	return nil
}
