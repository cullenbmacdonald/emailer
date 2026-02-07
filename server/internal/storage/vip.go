package storage

import (
	"context"
	"fmt"
	"strings"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// VIPStore provides CRUD operations for the vip_senders table.
type VIPStore struct {
	pool *pgxpool.Pool
}

// NewVIPStore creates a new VIPStore.
func NewVIPStore(pool *pgxpool.Pool) *VIPStore {
	return &VIPStore{pool: pool}
}

// AddVIPSender adds a new VIP sender. Returns the created entry.
func (s *VIPStore) AddVIPSender(ctx context.Context, email, name string) (*models.VIPSender, error) {
	query := `
		INSERT INTO vip_senders (email, name)
		VALUES ($1, $2)
		RETURNING id, email, name, added_at`

	var vip models.VIPSender
	err := s.pool.QueryRow(ctx, query, email, name).Scan(
		&vip.ID, &vip.Email, &vip.Name, &vip.AddedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("add VIP sender %s: %w", email, err)
	}
	return &vip, nil
}

// RemoveVIPSender deletes a VIP sender by ID.
func (s *VIPStore) RemoveVIPSender(ctx context.Context, id string) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM vip_senders WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("remove VIP sender %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// ListVIPSenders returns all VIP senders ordered by added_at DESC.
func (s *VIPStore) ListVIPSenders(ctx context.Context) ([]models.VIPSender, error) {
	query := `
		SELECT id, email, name, added_at
		FROM vip_senders
		ORDER BY added_at DESC`

	rows, err := s.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("list VIP senders: %w", err)
	}
	defer rows.Close()

	var vips []models.VIPSender
	for rows.Next() {
		var vip models.VIPSender
		if err := rows.Scan(&vip.ID, &vip.Email, &vip.Name, &vip.AddedAt); err != nil {
			return nil, fmt.Errorf("scan VIP sender: %w", err)
		}
		vips = append(vips, vip)
	}
	if vips == nil {
		vips = []models.VIPSender{}
	}
	return vips, rows.Err()
}

// IsVIPSender checks if an email address matches a VIP sender.
// Supports both exact email match and domain match (entries starting with @).
func (s *VIPStore) IsVIPSender(ctx context.Context, email string) (bool, error) {
	// Extract domain from email
	domain := ""
	if atIdx := strings.LastIndex(email, "@"); atIdx >= 0 {
		domain = "@" + email[atIdx+1:]
	}

	query := `
		SELECT EXISTS(
			SELECT 1 FROM vip_senders
			WHERE LOWER(email) = LOWER($1)
			   OR LOWER(email) = LOWER($2)
		)`

	var exists bool
	err := s.pool.QueryRow(ctx, query, email, domain).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check VIP sender %s: %w", email, err)
	}
	return exists, nil
}
