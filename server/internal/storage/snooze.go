package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SnoozeStore provides CRUD operations for the snooze_states table.
type SnoozeStore struct {
	pool *pgxpool.Pool
}

// NewSnoozeStore creates a new SnoozeStore.
func NewSnoozeStore(pool *pgxpool.Pool) *SnoozeStore {
	return &SnoozeStore{pool: pool}
}

// CreateSnooze inserts a new active snooze for an email.
func (s *SnoozeStore) CreateSnooze(ctx context.Context, emailID string, returnAt time.Time, snoozeCount int) (*models.SnoozeState, error) {
	query := `
		INSERT INTO snooze_states (email_id, return_at, snooze_count)
		VALUES ($1, $2, $3)
		RETURNING id, email_id, snoozed_at, return_at, snooze_count, is_active`

	var snz models.SnoozeState
	err := s.pool.QueryRow(ctx, query, emailID, returnAt, snoozeCount).Scan(
		&snz.ID, &snz.EmailID, &snz.SnoozedAt, &snz.ReturnAt, &snz.SnoozeCount, &snz.IsActive,
	)
	if err != nil {
		return nil, fmt.Errorf("create snooze for email %s: %w", emailID, err)
	}
	return &snz, nil
}

// GetActiveSnooze returns the active snooze for an email, or pgx.ErrNoRows if none.
func (s *SnoozeStore) GetActiveSnooze(ctx context.Context, emailID string) (*models.SnoozeState, error) {
	query := `
		SELECT id, email_id, snoozed_at, return_at, snooze_count, is_active
		FROM snooze_states
		WHERE email_id = $1 AND is_active = TRUE`

	var snz models.SnoozeState
	err := s.pool.QueryRow(ctx, query, emailID).Scan(
		&snz.ID, &snz.EmailID, &snz.SnoozedAt, &snz.ReturnAt, &snz.SnoozeCount, &snz.IsActive,
	)
	if err != nil {
		return nil, fmt.Errorf("get active snooze for email %s: %w", emailID, err)
	}
	return &snz, nil
}

// DeactivateSnooze marks the active snooze for an email as inactive.
func (s *SnoozeStore) DeactivateSnooze(ctx context.Context, emailID string) error {
	query := `
		UPDATE snooze_states
		SET is_active = FALSE
		WHERE email_id = $1 AND is_active = TRUE`

	tag, err := s.pool.Exec(ctx, query, emailID)
	if err != nil {
		return fmt.Errorf("deactivate snooze for email %s: %w", emailID, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// GetExpiredSnoozes returns all active snoozes whose return_at is at or before the given time.
func (s *SnoozeStore) GetExpiredSnoozes(ctx context.Context, now time.Time) ([]models.SnoozeState, error) {
	query := `
		SELECT id, email_id, snoozed_at, return_at, snooze_count, is_active
		FROM snooze_states
		WHERE is_active = TRUE AND return_at <= $1
		ORDER BY return_at ASC`

	rows, err := s.pool.Query(ctx, query, now)
	if err != nil {
		return nil, fmt.Errorf("get expired snoozes: %w", err)
	}
	defer rows.Close()

	var snoozes []models.SnoozeState
	for rows.Next() {
		var snz models.SnoozeState
		if err := rows.Scan(&snz.ID, &snz.EmailID, &snz.SnoozedAt, &snz.ReturnAt, &snz.SnoozeCount, &snz.IsActive); err != nil {
			return nil, fmt.Errorf("scan expired snooze: %w", err)
		}
		snoozes = append(snoozes, snz)
	}
	return snoozes, rows.Err()
}

// UpdateSnooze updates an existing snooze's return_at and snooze_count.
func (s *SnoozeStore) UpdateSnooze(ctx context.Context, snoozeID string, returnAt time.Time, snoozeCount int) error {
	query := `
		UPDATE snooze_states
		SET return_at = $2, snooze_count = $3, snoozed_at = NOW()
		WHERE id = $1 AND is_active = TRUE`

	tag, err := s.pool.Exec(ctx, query, snoozeID, returnAt, snoozeCount)
	if err != nil {
		return fmt.Errorf("update snooze %s: %w", snoozeID, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}
