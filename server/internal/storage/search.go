package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SearchStore provides full-text search over the emails table.
type SearchStore struct {
	pool *pgxpool.Pool
}

// NewSearchStore creates a new SearchStore.
func NewSearchStore(pool *pgxpool.Pool) *SearchStore {
	return &SearchStore{pool: pool}
}

// SearchEmails performs full-text search using PostgreSQL tsvector/tsquery.
// Returns results ranked by relevance with highlighted snippets.
func (s *SearchStore) SearchEmails(ctx context.Context, query string, accountID string, cursor string, limit int) (*models.SearchResponse, error) {
	limit = models.ClampPageSize(limit)

	var args []any
	argIdx := 0
	nextArg := func() string {
		argIdx++
		return fmt.Sprintf("$%d", argIdx)
	}

	// The search query
	queryArg := nextArg()
	args = append(args, query)

	var where []string
	where = append(where, fmt.Sprintf("e.search_vector @@ plainto_tsquery('english', %s)", queryArg))

	if accountID != "" {
		where = append(where, "e.account_id = "+nextArg())
		args = append(args, accountID)
	}

	if cursor != "" {
		parts, err := models.DecodeCursor(cursor)
		if err != nil {
			return nil, fmt.Errorf("invalid cursor: %w", err)
		}
		if len(parts) < 2 {
			return nil, fmt.Errorf("invalid cursor: need 2 parts")
		}
		where = append(where, fmt.Sprintf("(e.received_at, e.id) < (%s, %s)", nextArg(), nextArg()))
		args = append(args, parts[0], parts[1])
	}

	whereClause := "WHERE " + joinAnd(where)

	args = append(args, limit+1)
	limitArg := fmt.Sprintf("$%d", argIdx+1)

	sqlQuery := fmt.Sprintf(`
		SELECT
			e.id, e.account_id, e.message_id, e.thread_id,
			e.from_address, e.from_name, e.to_addresses, e.cc_addresses,
			e.subject, e.snippet, e.received_at,
			e.has_attachments, e.is_read, e.is_archived, e.labels,
			e.last_read_at, e.read_progress,
			a.color, a.name,
			c.classification, c.confidence, c.classified_by, c.reason, c.is_overridden,
			ts_rank(e.search_vector, plainto_tsquery('english', %s)) AS rank,
			ts_headline('english', COALESCE(e.subject, '') || ' ' || COALESCE(e.text_body, ''),
				plainto_tsquery('english', %s),
				'StartSel=<mark>, StopSel=</mark>, MaxFragments=2, MaxWords=30, MinWords=15'
			) AS highlight_snippet
		FROM emails e
		JOIN accounts a ON a.id = e.account_id
		LEFT JOIN classifications c ON c.email_id = e.id
		%s
		ORDER BY rank DESC, e.received_at DESC, e.id DESC
		LIMIT %s`,
		queryArg, queryArg, whereClause, limitArg)

	rows, err := s.pool.Query(ctx, sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("search emails: %w", err)
	}
	defer rows.Close()

	var results []models.SearchResult
	for rows.Next() {
		var (
			email       models.Email
			toJSON      []byte
			ccJSON      []byte
			labelsJSON  []byte
			acctColor   string
			acctName    string
			classValue  *string
			classConf   *float64
			classBy     *string
			classReason *string
			classOverr  *bool
			rank        float64
			highlight   string
		)

		if err := rows.Scan(
			&email.ID, &email.AccountID, &email.MessageID, &email.ThreadID,
			&email.From.Email, &email.From.Name, &toJSON, &ccJSON,
			&email.Subject, &email.Snippet, &email.ReceivedAt,
			&email.HasAttachments, &email.IsRead, &email.IsArchived, &labelsJSON,
			&email.LastReadAt, &email.ReadProgress,
			&acctColor, &acctName,
			&classValue, &classConf, &classBy, &classReason, &classOverr,
			&rank, &highlight,
		); err != nil {
			return nil, fmt.Errorf("scan search result: %w", err)
		}

		// Unmarshal JSON fields
		if len(toJSON) > 0 {
			if err := json.Unmarshal(toJSON, &email.To); err != nil {
				return nil, fmt.Errorf("unmarshal to_addresses: %w", err)
			}
		}
		if len(ccJSON) > 0 {
			if err := json.Unmarshal(ccJSON, &email.CC); err != nil {
				return nil, fmt.Errorf("unmarshal cc_addresses: %w", err)
			}
		}
		if len(labelsJSON) > 0 {
			if err := json.Unmarshal(labelsJSON, &email.Labels); err != nil {
				return nil, fmt.Errorf("unmarshal labels: %w", err)
			}
		}

		email.AccountColor = acctColor
		email.AccountName = acctName

		if classValue != nil {
			email.Classification = &models.Classification{
				Classification: *classValue,
				Confidence:     derefFloat(classConf),
				ClassifiedBy:   derefStr(classBy),
				Reason:         derefStr(classReason),
				IsOverridden:   derefBool(classOverr),
			}
		}

		results = append(results, models.SearchResult{
			Email:            email,
			HighlightSnippet: highlight,
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate search results: %w", err)
	}

	hasMore := len(results) > limit
	if hasMore {
		results = results[:limit]
	}

	resp := &models.SearchResponse{
		Data:    results,
		HasMore: hasMore,
		Query:   query,
	}
	if resp.Data == nil {
		resp.Data = []models.SearchResult{}
	}
	if hasMore && len(results) > 0 {
		last := results[len(results)-1]
		resp.NextCursor = models.EncodeCursor(
			last.Email.ReceivedAt.UTC().Format(time.RFC3339Nano),
			last.Email.ID,
		)
	}
	return resp, nil
}

// joinAnd joins conditions with AND.
func joinAnd(parts []string) string {
	result := ""
	for i, p := range parts {
		if i > 0 {
			result += " AND "
		}
		result += p
	}
	return result
}
