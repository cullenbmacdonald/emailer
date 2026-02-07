package storage

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RecommendationStore provides CRUD operations for recommendations and recommendation_sources.
type RecommendationStore struct {
	pool *pgxpool.Pool
}

// NewRecommendationStore creates a new RecommendationStore.
func NewRecommendationStore(pool *pgxpool.Pool) *RecommendationStore {
	return &RecommendationStore{pool: pool}
}

// RecommendationListOptions holds parameters for listing recommendations.
type RecommendationListOptions struct {
	Type          string
	Status        string
	AccountID     string
	SourceEmailID string
	Cursor        string
	Limit         int
}

// CreateRecommendation inserts a new recommendation and returns it.
func (s *RecommendationStore) CreateRecommendation(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error) {
	query := `
		INSERT INTO recommendations (
			email_id, type, title, creator,
			source_newsletter_name, source_date, context_snippet,
			full_context, status, is_user_added
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at`

	var fullContext *string
	var ca, ua time.Time
	err := s.pool.QueryRow(ctx, query,
		nilIfEmpty(r.SourceEmailID), r.Type, r.Title, r.Creator,
		r.SourceNewsletterName, r.SourceDate, r.ContextSnippet,
		fullContext, r.Status, r.IsUserAdded,
	).Scan(&r.ID, &ca, &ua)
	if err != nil {
		return nil, fmt.Errorf("create recommendation: %w", err)
	}
	r.CreatedAt = ca
	return r, nil
}

// GetRecommendation returns a recommendation by ID with full context.
func (s *RecommendationStore) GetRecommendation(ctx context.Context, id string) (*models.RecommendationDetail, error) {
	query := `
		SELECT id, type, title, creator, source_newsletter_name,
			   email_id, source_date, context_snippet, full_context,
			   status, duplicate_count, is_user_added, created_at
		FROM recommendations
		WHERE id = $1`

	var detail models.RecommendationDetail
	var emailID *string
	var fullCtx *string
	var creator *string
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&detail.Recommendation.ID, &detail.Recommendation.Type,
		&detail.Recommendation.Title, &creator,
		&detail.Recommendation.SourceNewsletterName,
		&emailID, &detail.Recommendation.SourceDate,
		&detail.Recommendation.ContextSnippet, &fullCtx,
		&detail.Recommendation.Status, &detail.Recommendation.DuplicateCount,
		&detail.Recommendation.IsUserAdded, &detail.Recommendation.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get recommendation %s: %w", id, err)
	}
	if emailID != nil {
		detail.Recommendation.SourceEmailID = *emailID
	}
	if fullCtx != nil {
		detail.FullContext = *fullCtx
	}
	if creator != nil {
		detail.Recommendation.Creator = *creator
	}

	// Fetch duplicate sources
	sources, err := s.GetDuplicateSources(ctx, id)
	if err != nil {
		return nil, err
	}
	detail.DuplicateSources = sources

	return &detail, nil
}

// ListRecommendations returns a paginated list of recommendations with optional filters.
func (s *RecommendationStore) ListRecommendations(ctx context.Context, opts RecommendationListOptions) (*models.RecommendationListResponse, error) {
	limit := models.ClampPageSize(opts.Limit)

	var args []any
	argIdx := 0
	nextArg := func() string {
		argIdx++
		return fmt.Sprintf("$%d", argIdx)
	}

	var where []string

	if opts.Type != "" {
		where = append(where, "r.type = "+nextArg())
		args = append(args, opts.Type)
	}
	if opts.Status != "" {
		where = append(where, "r.status = "+nextArg())
		args = append(args, opts.Status)
	}
	if opts.AccountID != "" {
		where = append(where, "e.account_id = "+nextArg())
		args = append(args, opts.AccountID)
	}
	if opts.SourceEmailID != "" {
		where = append(where, "r.email_id = "+nextArg())
		args = append(args, opts.SourceEmailID)
	}

	if opts.Cursor != "" {
		parts, err := models.DecodeCursor(opts.Cursor)
		if err != nil {
			return nil, fmt.Errorf("invalid cursor: %w", err)
		}
		if len(parts) < 2 {
			return nil, fmt.Errorf("invalid cursor: need 2 parts")
		}
		where = append(where, fmt.Sprintf("(r.created_at, r.id) < (%s, %s)", nextArg(), nextArg()))
		args = append(args, parts[0], parts[1])
	}

	whereClause := ""
	if len(where) > 0 {
		whereClause = "WHERE " + strings.Join(where, " AND ")
	}

	args = append(args, limit+1)
	limitArg := fmt.Sprintf("$%d", argIdx+1)

	query := fmt.Sprintf(`
		SELECT r.id, r.type, r.title, r.creator, r.source_newsletter_name,
			   r.email_id, r.source_date, r.context_snippet,
			   r.status, r.duplicate_count, r.is_user_added, r.created_at
		FROM recommendations r
		LEFT JOIN emails e ON e.id = r.email_id
		%s
		ORDER BY r.created_at DESC, r.id DESC
		LIMIT %s`, whereClause, limitArg)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list recommendations: %w", err)
	}
	defer rows.Close()

	var recs []models.Recommendation
	for rows.Next() {
		var rec models.Recommendation
		var emailID *string
		var creator *string
		if err := rows.Scan(
			&rec.ID, &rec.Type, &rec.Title, &creator,
			&rec.SourceNewsletterName, &emailID, &rec.SourceDate,
			&rec.ContextSnippet, &rec.Status, &rec.DuplicateCount,
			&rec.IsUserAdded, &rec.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan recommendation: %w", err)
		}
		if emailID != nil {
			rec.SourceEmailID = *emailID
		}
		if creator != nil {
			rec.Creator = *creator
		}
		recs = append(recs, rec)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate recommendations: %w", err)
	}

	hasMore := len(recs) > limit
	if hasMore {
		recs = recs[:limit]
	}

	resp := &models.RecommendationListResponse{
		Data:    recs,
		HasMore: hasMore,
	}
	if resp.Data == nil {
		resp.Data = []models.Recommendation{}
	}
	if hasMore && len(recs) > 0 {
		last := recs[len(recs)-1]
		resp.NextCursor = models.EncodeCursor(last.CreatedAt.UTC().Format(time.RFC3339Nano), last.ID)
	}
	return resp, nil
}

// UpdateRecommendationStatus changes the status of a recommendation.
func (s *RecommendationStore) UpdateRecommendationStatus(ctx context.Context, id, status string) error {
	query := `UPDATE recommendations SET status = $2, updated_at = NOW() WHERE id = $1`
	tag, err := s.pool.Exec(ctx, query, id, status)
	if err != nil {
		return fmt.Errorf("update recommendation status %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// FindSimilarRecommendation checks for a duplicate recommendation by title and type (case-insensitive).
func (s *RecommendationStore) FindSimilarRecommendation(ctx context.Context, title, recType string) (*models.Recommendation, error) {
	query := `
		SELECT id, type, title, creator, source_newsletter_name,
			   email_id, source_date, context_snippet,
			   status, duplicate_count, is_user_added, created_at
		FROM recommendations
		WHERE LOWER(TRIM(title)) = LOWER(TRIM($1)) AND type = $2
		LIMIT 1`

	var rec models.Recommendation
	var emailID *string
	var creator *string
	err := s.pool.QueryRow(ctx, query, title, recType).Scan(
		&rec.ID, &rec.Type, &rec.Title, &creator,
		&rec.SourceNewsletterName, &emailID, &rec.SourceDate,
		&rec.ContextSnippet, &rec.Status, &rec.DuplicateCount,
		&rec.IsUserAdded, &rec.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("find similar recommendation: %w", err)
	}
	if emailID != nil {
		rec.SourceEmailID = *emailID
	}
	if creator != nil {
		rec.Creator = *creator
	}
	return &rec, nil
}

// IncrementDuplicateCount bumps the duplicate_count for a recommendation.
func (s *RecommendationStore) IncrementDuplicateCount(ctx context.Context, id string) error {
	query := `UPDATE recommendations SET duplicate_count = duplicate_count + 1, updated_at = NOW() WHERE id = $1`
	_, err := s.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("increment duplicate count %s: %w", id, err)
	}
	return nil
}

// AddDuplicateSource records a source where a recommendation was mentioned.
func (s *RecommendationStore) AddDuplicateSource(ctx context.Context, recommendationID, emailID, newsletterName, contextSnippet string, date time.Time) error {
	query := `
		INSERT INTO recommendation_sources (recommendation_id, email_id, newsletter_name, date, context_snippet)
		VALUES ($1, $2, $3, $4, $5)`

	_, err := s.pool.Exec(ctx, query,
		recommendationID, nilIfEmpty(emailID), newsletterName, date, contextSnippet,
	)
	if err != nil {
		return fmt.Errorf("add duplicate source for recommendation %s: %w", recommendationID, err)
	}
	return nil
}

// GetDuplicateSources returns all duplicate sources for a recommendation.
func (s *RecommendationStore) GetDuplicateSources(ctx context.Context, recommendationID string) ([]models.DuplicateSource, error) {
	query := `
		SELECT newsletter_name, email_id, date, context_snippet
		FROM recommendation_sources
		WHERE recommendation_id = $1
		ORDER BY date DESC`

	rows, err := s.pool.Query(ctx, query, recommendationID)
	if err != nil {
		return nil, fmt.Errorf("get duplicate sources for %s: %w", recommendationID, err)
	}
	defer rows.Close()

	var sources []models.DuplicateSource
	for rows.Next() {
		var src models.DuplicateSource
		var emailID *string
		if err := rows.Scan(&src.NewsletterName, &emailID, &src.Date, &src.ContextSnippet); err != nil {
			return nil, fmt.Errorf("scan duplicate source: %w", err)
		}
		if emailID != nil {
			src.EmailID = *emailID
		}
		sources = append(sources, src)
	}
	if sources == nil {
		sources = []models.DuplicateSource{}
	}
	return sources, rows.Err()
}

// nilIfEmpty returns nil if the string is empty, otherwise a pointer to it.
func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}
