package storage

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DraftStore provides CRUD operations for the drafts table.
type DraftStore struct {
	pool *pgxpool.Pool
}

// NewDraftStore creates a new DraftStore.
func NewDraftStore(pool *pgxpool.Pool) *DraftStore {
	return &DraftStore{pool: pool}
}

const defaultDraftLimit = 50

// ListDrafts returns drafts ordered by updated_at DESC with cursor pagination.
func (s *DraftStore) ListDrafts(ctx context.Context, cursor string, limit int) (*models.DraftListResponse, error) {
	if limit <= 0 {
		limit = defaultDraftLimit
	}

	// Fetch one extra to determine has_more.
	fetchLimit := limit + 1

	var rows pgx.Rows
	var err error

	if cursor != "" {
		cursorTime, decErr := decodeDraftCursor(cursor)
		if decErr != nil {
			return nil, fmt.Errorf("decode draft cursor: %w", decErr)
		}
		rows, err = s.pool.Query(ctx, `
			SELECT id, account_id, to_addresses, cc_addresses, bcc_addresses,
			       subject, body, html_body, in_reply_to, created_at, updated_at
			FROM drafts
			WHERE updated_at < $1
			ORDER BY updated_at DESC
			LIMIT $2`, cursorTime, fetchLimit)
	} else {
		rows, err = s.pool.Query(ctx, `
			SELECT id, account_id, to_addresses, cc_addresses, bcc_addresses,
			       subject, body, html_body, in_reply_to, created_at, updated_at
			FROM drafts
			ORDER BY updated_at DESC
			LIMIT $1`, fetchLimit)
	}
	if err != nil {
		return nil, fmt.Errorf("list drafts: %w", err)
	}
	defer rows.Close()

	drafts := make([]models.Draft, 0, limit)
	for rows.Next() {
		d, scanErr := scanDraft(rows)
		if scanErr != nil {
			return nil, scanErr
		}
		drafts = append(drafts, *d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate drafts: %w", err)
	}

	resp := &models.DraftListResponse{
		Data:    drafts,
		HasMore: len(drafts) > limit,
	}
	if resp.HasMore {
		resp.Data = resp.Data[:limit]
		last := resp.Data[len(resp.Data)-1]
		resp.NextCursor = encodeDraftCursor(last.UpdatedAt)
	}
	return resp, nil
}

// CreateDraft inserts a new draft and returns it with the generated ID.
func (s *DraftStore) CreateDraft(ctx context.Context, d *models.Draft) (*models.Draft, error) {
	toJSON, _ := json.Marshal(d.To)
	ccJSON, _ := json.Marshal(d.CC)
	bccJSON, _ := json.Marshal(d.BCC)

	query := `
		INSERT INTO drafts (account_id, to_addresses, cc_addresses, bcc_addresses,
		                     subject, body, html_body, in_reply_to)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, account_id, to_addresses, cc_addresses, bcc_addresses,
		          subject, body, html_body, in_reply_to, created_at, updated_at`

	row := s.pool.QueryRow(ctx, query,
		d.AccountID, toJSON, ccJSON, bccJSON,
		d.Subject, d.Body, d.HTMLBody, nullString(d.InReplyTo))

	created, err := scanDraftRow(row)
	if err != nil {
		return nil, fmt.Errorf("create draft: %w", err)
	}
	return created, nil
}

// UpdateDraft updates an existing draft by ID.
func (s *DraftStore) UpdateDraft(ctx context.Context, id string, d *models.Draft) (*models.Draft, error) {
	toJSON, _ := json.Marshal(d.To)
	ccJSON, _ := json.Marshal(d.CC)
	bccJSON, _ := json.Marshal(d.BCC)

	query := `
		UPDATE drafts
		SET account_id = $2, to_addresses = $3, cc_addresses = $4, bcc_addresses = $5,
		    subject = $6, body = $7, html_body = $8, in_reply_to = $9, updated_at = NOW()
		WHERE id = $1
		RETURNING id, account_id, to_addresses, cc_addresses, bcc_addresses,
		          subject, body, html_body, in_reply_to, created_at, updated_at`

	row := s.pool.QueryRow(ctx, query,
		id, d.AccountID, toJSON, ccJSON, bccJSON,
		d.Subject, d.Body, d.HTMLBody, nullString(d.InReplyTo))

	updated, err := scanDraftRow(row)
	if err != nil {
		return nil, fmt.Errorf("update draft %s: %w", id, err)
	}
	return updated, nil
}

// DeleteDraft deletes a draft by ID.
func (s *DraftStore) DeleteDraft(ctx context.Context, id string) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM drafts WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("delete draft %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// scanDraft scans a draft from a rows iterator.
func scanDraft(rows pgx.Rows) (*models.Draft, error) {
	var d models.Draft
	var toJSON, ccJSON, bccJSON []byte
	var inReplyTo *string

	if err := rows.Scan(
		&d.ID, &d.AccountID, &toJSON, &ccJSON, &bccJSON,
		&d.Subject, &d.Body, &d.HTMLBody, &inReplyTo,
		&d.CreatedAt, &d.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("scan draft: %w", err)
	}

	_ = json.Unmarshal(toJSON, &d.To)
	_ = json.Unmarshal(ccJSON, &d.CC)
	_ = json.Unmarshal(bccJSON, &d.BCC)
	if inReplyTo != nil {
		d.InReplyTo = *inReplyTo
	}
	return &d, nil
}

// scanDraftRow scans a draft from a single row.
func scanDraftRow(row pgx.Row) (*models.Draft, error) {
	var d models.Draft
	var toJSON, ccJSON, bccJSON []byte
	var inReplyTo *string

	if err := row.Scan(
		&d.ID, &d.AccountID, &toJSON, &ccJSON, &bccJSON,
		&d.Subject, &d.Body, &d.HTMLBody, &inReplyTo,
		&d.CreatedAt, &d.UpdatedAt,
	); err != nil {
		return nil, err
	}

	_ = json.Unmarshal(toJSON, &d.To)
	_ = json.Unmarshal(ccJSON, &d.CC)
	_ = json.Unmarshal(bccJSON, &d.BCC)
	if inReplyTo != nil {
		d.InReplyTo = *inReplyTo
	}
	return &d, nil
}

func nullString(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func encodeDraftCursor(t time.Time) string {
	return base64.URLEncoding.EncodeToString([]byte(t.Format(time.RFC3339Nano)))
}

func decodeDraftCursor(cursor string) (time.Time, error) {
	b, err := base64.URLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, err
	}
	return time.Parse(time.RFC3339Nano, string(b))
}
