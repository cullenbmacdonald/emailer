package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DigestStore provides CRUD operations for the digests table.
type DigestStore struct {
	pool *pgxpool.Pool
}

// NewDigestStore creates a new DigestStore.
func NewDigestStore(pool *pgxpool.Pool) *DigestStore {
	return &DigestStore{pool: pool}
}

// SaveDigest inserts a new digest with its sections payload as JSONB.
func (s *DigestStore) SaveDigest(ctx context.Context, d *models.DailyDigest) (*models.DailyDigest, error) {
	payload, err := json.Marshal(d.Sections)
	if err != nil {
		return nil, fmt.Errorf("marshal digest sections: %w", err)
	}

	query := `
		INSERT INTO digests (digest_type, payload)
		VALUES ($1, $2)
		RETURNING id, generated_at, is_read, created_at`

	var ca time.Time
	err = s.pool.QueryRow(ctx, query, d.DigestType, payload).Scan(
		&d.ID, &d.GeneratedAt, &d.IsRead, &ca,
	)
	if err != nil {
		return nil, fmt.Errorf("save digest: %w", err)
	}
	return d, nil
}

// GetDigest returns a digest by ID with its sections parsed from JSONB.
func (s *DigestStore) GetDigest(ctx context.Context, id string) (*models.DailyDigest, error) {
	query := `
		SELECT id, digest_type, generated_at, is_read, payload
		FROM digests
		WHERE id = $1`

	var d models.DailyDigest
	var payload []byte
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&d.ID, &d.DigestType, &d.GeneratedAt, &d.IsRead, &payload,
	)
	if err != nil {
		return nil, fmt.Errorf("get digest %s: %w", id, err)
	}
	if err := json.Unmarshal(payload, &d.Sections); err != nil {
		return nil, fmt.Errorf("unmarshal digest sections: %w", err)
	}
	return &d, nil
}

// GetLatestDigest returns the most recent digest, optionally filtered by type.
func (s *DigestStore) GetLatestDigest(ctx context.Context, digestType string) (*models.DailyDigest, error) {
	var args []any
	query := `SELECT id, digest_type, generated_at, is_read, payload FROM digests`

	if digestType != "" {
		query += ` WHERE digest_type = $1`
		args = append(args, digestType)
	}
	query += ` ORDER BY generated_at DESC LIMIT 1`

	var d models.DailyDigest
	var payload []byte
	err := s.pool.QueryRow(ctx, query, args...).Scan(
		&d.ID, &d.DigestType, &d.GeneratedAt, &d.IsRead, &payload,
	)
	if err != nil {
		return nil, fmt.Errorf("get latest digest: %w", err)
	}
	if err := json.Unmarshal(payload, &d.Sections); err != nil {
		return nil, fmt.Errorf("unmarshal digest sections: %w", err)
	}
	return &d, nil
}

// ListDigests returns a paginated list of digest summaries.
func (s *DigestStore) ListDigests(ctx context.Context, cursor string, limit int) (*models.DigestListResponse, error) {
	limit = models.ClampPageSize(limit)

	var args []any
	argIdx := 0
	nextArg := func() string {
		argIdx++
		return fmt.Sprintf("$%d", argIdx)
	}

	var where []string
	if cursor != "" {
		parts, err := models.DecodeCursor(cursor)
		if err != nil {
			return nil, fmt.Errorf("invalid cursor: %w", err)
		}
		if len(parts) < 2 {
			return nil, fmt.Errorf("invalid cursor: need 2 parts")
		}
		where = append(where, fmt.Sprintf("(generated_at, id) < (%s, %s)", nextArg(), nextArg()))
		args = append(args, parts[0], parts[1])
	}

	whereClause := ""
	if len(where) > 0 {
		whereClause = "WHERE " + where[0]
	}

	args = append(args, limit+1)
	limitArg := fmt.Sprintf("$%d", argIdx+1)

	query := fmt.Sprintf(`
		SELECT id, digest_type, generated_at, is_read
		FROM digests
		%s
		ORDER BY generated_at DESC, id DESC
		LIMIT %s`, whereClause, limitArg)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list digests: %w", err)
	}
	defer rows.Close()

	var summaries []models.DigestSummary
	for rows.Next() {
		var ds models.DigestSummary
		if err := rows.Scan(&ds.ID, &ds.DigestType, &ds.GeneratedAt, &ds.IsRead); err != nil {
			return nil, fmt.Errorf("scan digest summary: %w", err)
		}
		summaries = append(summaries, ds)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate digests: %w", err)
	}

	hasMore := len(summaries) > limit
	if hasMore {
		summaries = summaries[:limit]
	}

	resp := &models.DigestListResponse{
		Data:    summaries,
		HasMore: hasMore,
	}
	if resp.Data == nil {
		resp.Data = []models.DigestSummary{}
	}
	if hasMore && len(summaries) > 0 {
		last := summaries[len(summaries)-1]
		resp.NextCursor = models.EncodeCursor(last.GeneratedAt.UTC().Format(time.RFC3339Nano), last.ID)
	}
	return resp, nil
}

// UpdateDigest updates a digest's metadata (e.g., mark as read).
func (s *DigestStore) UpdateDigest(ctx context.Context, id string, update models.DigestUpdateRequest) error {
	if update.IsRead == nil {
		return nil
	}
	query := `UPDATE digests SET is_read = $2 WHERE id = $1`
	tag, err := s.pool.Exec(ctx, query, id, *update.IsRead)
	if err != nil {
		return fmt.Errorf("update digest %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}
