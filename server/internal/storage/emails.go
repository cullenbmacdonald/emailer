package storage

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// View name constants for email listing.
const (
	ViewActionQueue  = "action_queue"
	ViewReadingQueue = "reading_queue"
	ViewFiltered     = "filtered"
	ViewAllInboxes   = "all_inboxes"
)

// EmailStore provides CRUD operations for the emails table.
type EmailStore struct {
	pool *pgxpool.Pool
}

// NewEmailStore creates a new EmailStore.
func NewEmailStore(pool *pgxpool.Pool) *EmailStore {
	return &EmailStore{pool: pool}
}

// EmailListOptions holds parameters for listing emails.
type EmailListOptions struct {
	View       string // required: action_queue, reading_queue, filtered, all_inboxes
	AccountID  string // optional
	IsRead     *bool  // optional
	IsArchived *bool  // optional
	Cursor     string // opaque cursor
	Limit      int
}

// CreateEmail inserts a new email and returns it with the generated ID.
func (s *EmailStore) CreateEmail(ctx context.Context, e *models.Email, htmlBody, textBody string) (*models.Email, error) {
	toJSON, err := json.Marshal(e.To)
	if err != nil {
		return nil, fmt.Errorf("marshal to_addresses: %w", err)
	}
	ccJSON, err := json.Marshal(e.CC)
	if err != nil {
		return nil, fmt.Errorf("marshal cc_addresses: %w", err)
	}
	labelsJSON, err := json.Marshal(e.Labels)
	if err != nil {
		return nil, fmt.Errorf("marshal labels: %w", err)
	}

	query := `
		INSERT INTO emails (
			account_id, message_id, thread_id, folder,
			from_address, from_name, to_addresses, cc_addresses,
			subject, snippet, text_body, html_body,
			received_at, has_attachments, is_read, is_archived, labels
		) VALUES (
			$1, $2, $3, $4,
			$5, $6, $7, $8,
			$9, $10, $11, $12,
			$13, $14, $15, $16, $17
		)
		RETURNING id, created_at, updated_at`

	var ca, ua time.Time
	err = s.pool.QueryRow(ctx, query,
		e.AccountID, e.MessageID, e.ThreadID, "INBOX",
		e.From.Email, e.From.Name, toJSON, ccJSON,
		e.Subject, e.Snippet, textBody, htmlBody,
		e.ReceivedAt, e.HasAttachments, e.IsRead, e.IsArchived, labelsJSON,
	).Scan(&e.ID, &ca, &ua)
	if err != nil {
		return nil, fmt.Errorf("insert email: %w", err)
	}

	return e, nil
}

// GetEmail returns a single email by ID, including classification and snooze state.
func (s *EmailStore) GetEmail(ctx context.Context, id string) (*models.Email, error) {
	query := `
		SELECT
			e.id, e.account_id, e.message_id, e.thread_id,
			e.from_address, e.from_name, e.to_addresses, e.cc_addresses,
			e.subject, e.snippet, e.received_at,
			e.has_attachments, e.is_read, e.is_archived, e.labels,
			e.last_read_at, e.read_progress,
			a.color, a.name,
			c.classification, c.confidence, c.classified_by, c.reason, c.is_overridden,
			ss.id, ss.email_id, ss.snoozed_at, ss.return_at, ss.snooze_count, ss.is_active
		FROM emails e
		JOIN accounts a ON a.id = e.account_id
		LEFT JOIN classifications c ON c.email_id = e.id
		LEFT JOIN snooze_states ss ON ss.email_id = e.id AND ss.is_active = TRUE
		WHERE e.id = $1`

	email, err := scanEmail(s.pool.QueryRow(ctx, query, id))
	if err != nil {
		return nil, fmt.Errorf("get email %s: %w", id, err)
	}
	return email, nil
}

// GetEmailDetail returns the full email including body content.
func (s *EmailStore) GetEmailDetail(ctx context.Context, id string) (*models.EmailDetail, error) {
	query := `
		SELECT
			e.id, e.account_id, e.message_id, e.thread_id,
			e.from_address, e.from_name, e.to_addresses, e.cc_addresses,
			e.subject, e.snippet, e.received_at,
			e.has_attachments, e.is_read, e.is_archived, e.labels,
			e.last_read_at, e.read_progress,
			a.color, a.name,
			c.classification, c.confidence, c.classified_by, c.reason, c.is_overridden,
			ss.id, ss.email_id, ss.snoozed_at, ss.return_at, ss.snooze_count, ss.is_active,
			COALESCE(e.html_body, ''), COALESCE(e.text_body, '')
		FROM emails e
		JOIN accounts a ON a.id = e.account_id
		LEFT JOIN classifications c ON c.email_id = e.id
		LEFT JOIN snooze_states ss ON ss.email_id = e.id AND ss.is_active = TRUE
		WHERE e.id = $1`

	row := s.pool.QueryRow(ctx, query, id)

	var htmlBody, textBody string
	email, err := scanEmailWithBody(row, &htmlBody, &textBody)
	if err != nil {
		return nil, fmt.Errorf("get email detail %s: %w", id, err)
	}

	detail := &models.EmailDetail{
		ID:          email.ID,
		Email:       *email,
		HTMLBody:    htmlBody,
		TextBody:    textBody,
		Attachments: []models.Attachment{},
	}
	return detail, nil
}

// ListEmails returns a paginated list of emails filtered by view.
func (s *EmailStore) ListEmails(ctx context.Context, opts EmailListOptions) (*models.EmailListResponse, error) {
	limit := models.ClampPageSize(opts.Limit)

	var args []any
	argIdx := 0
	nextArg := func() string {
		argIdx++
		return fmt.Sprintf("$%d", argIdx)
	}

	// Build WHERE clauses
	var where []string

	// View-based classification filter
	switch opts.View {
	case ViewActionQueue:
		where = append(where, "c.classification = "+nextArg())
		args = append(args, models.ClassActionRequired)
		// Exclude actively snoozed emails
		where = append(where, "(ss.is_active IS NULL OR ss.is_active = FALSE)")
	case ViewReadingQueue:
		where = append(where, "c.classification = "+nextArg())
		args = append(args, models.ClassNewsletter)
	case ViewFiltered:
		where = append(where, "c.classification = "+nextArg())
		args = append(args, models.ClassFiltered)
	case ViewAllInboxes:
		// No classification filter
	default:
		return nil, fmt.Errorf("invalid view: %s", opts.View)
	}

	// Optional filters
	if opts.AccountID != "" {
		where = append(where, "e.account_id = "+nextArg())
		args = append(args, opts.AccountID)
	}
	if opts.IsRead != nil {
		where = append(where, "e.is_read = "+nextArg())
		args = append(args, *opts.IsRead)
	}
	if opts.IsArchived != nil {
		where = append(where, "e.is_archived = "+nextArg())
		args = append(args, *opts.IsArchived)
	}

	// Cursor handling
	if opts.Cursor != "" {
		cursorWhere, cursorArgs, err := parseCursor(opts.View, opts.Cursor, &argIdx)
		if err != nil {
			return nil, fmt.Errorf("invalid cursor: %w", err)
		}
		where = append(where, cursorWhere)
		args = append(args, cursorArgs...)
	}

	whereClause := ""
	if len(where) > 0 {
		whereClause = "WHERE " + strings.Join(where, " AND ")
	}

	// Build ORDER BY based on view
	orderBy := buildOrderBy(opts.View)

	// Fetch limit+1 to determine has_more
	args = append(args, limit+1)
	limitArg := fmt.Sprintf("$%d", argIdx+1)

	query := fmt.Sprintf(`
		SELECT
			e.id, e.account_id, e.message_id, e.thread_id,
			e.from_address, e.from_name, e.to_addresses, e.cc_addresses,
			e.subject, e.snippet, e.received_at,
			e.has_attachments, e.is_read, e.is_archived, e.labels,
			e.last_read_at, e.read_progress,
			a.color, a.name,
			c.classification, c.confidence, c.classified_by, c.reason, c.is_overridden,
			ss.id, ss.email_id, ss.snoozed_at, ss.return_at, ss.snooze_count, ss.is_active
		FROM emails e
		JOIN accounts a ON a.id = e.account_id
		LEFT JOIN classifications c ON c.email_id = e.id
		LEFT JOIN snooze_states ss ON ss.email_id = e.id AND ss.is_active = TRUE
		%s
		ORDER BY %s
		LIMIT %s`,
		whereClause, orderBy, limitArg)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list emails: %w", err)
	}
	defer rows.Close()

	var emails []models.Email
	for rows.Next() {
		email, scanErr := scanEmailFromRows(rows)
		if scanErr != nil {
			return nil, fmt.Errorf("scan email row: %w", scanErr)
		}

		// Compute view-specific fields
		enrichViewFields(email, opts.View)

		emails = append(emails, *email)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate email rows: %w", err)
	}

	hasMore := len(emails) > limit
	if hasMore {
		emails = emails[:limit]
	}

	resp := &models.EmailListResponse{
		Data:    emails,
		HasMore: hasMore,
	}

	if hasMore && len(emails) > 0 {
		last := emails[len(emails)-1]
		resp.NextCursor = buildCursor(opts.View, &last)
	}

	// Ensure Data is never nil (empty slice for JSON)
	if resp.Data == nil {
		resp.Data = []models.Email{}
	}

	return resp, nil
}

// UpdateEmail updates mutable email fields and returns the updated email.
func (s *EmailStore) UpdateEmail(ctx context.Context, id string, update models.EmailUpdateRequest) (*models.Email, error) {
	var sets []string
	var args []any
	argIdx := 0
	nextArg := func() string {
		argIdx++
		return fmt.Sprintf("$%d", argIdx)
	}

	if update.IsRead != nil {
		sets = append(sets, "is_read = "+nextArg())
		args = append(args, *update.IsRead)
	}
	if update.IsArchived != nil {
		sets = append(sets, "is_archived = "+nextArg())
		args = append(args, *update.IsArchived)
	}
	if update.ReadProgress != nil {
		sets = append(sets, "read_progress = "+nextArg())
		args = append(args, *update.ReadProgress)
	}

	if len(sets) == 0 {
		// Nothing to update; just return the current email
		return s.GetEmail(ctx, id)
	}

	sets = append(sets, "updated_at = NOW()")

	// If marking as read, update last_read_at
	if update.IsRead != nil && *update.IsRead {
		sets = append(sets, "last_read_at = NOW()")
	}

	args = append(args, id)
	idArg := fmt.Sprintf("$%d", argIdx+1)

	query := fmt.Sprintf(`UPDATE emails SET %s WHERE id = %s`, strings.Join(sets, ", "), idArg)

	tag, err := s.pool.Exec(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("update email %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return nil, pgx.ErrNoRows
	}

	return s.GetEmail(ctx, id)
}

// DeleteEmail permanently deletes an email by ID.
func (s *EmailStore) DeleteEmail(ctx context.Context, id string) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM emails WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("delete email %s: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

// CountEmailsByView returns per-view email counts for an account.
func (s *EmailStore) CountEmailsByView(ctx context.Context, accountID string) (*models.AccountCounts, error) {
	query := `
		SELECT
			COUNT(*) FILTER (WHERE c.classification = 'action_required' AND e.is_archived = FALSE) AS action_queue,
			COUNT(*) FILTER (WHERE c.classification = 'newsletter' AND e.is_archived = FALSE) AS reading_queue,
			COUNT(*) FILTER (WHERE c.classification = 'filtered') AS filtered,
			COUNT(*) FILTER (WHERE c.classification = 'filtered' AND c.confidence < 0.80) AS filtered_borderline,
			COUNT(*) AS all_inboxes
		FROM emails e
		LEFT JOIN classifications c ON c.email_id = e.id
		WHERE e.account_id = $1`

	counts := &models.AccountCounts{}
	err := s.pool.QueryRow(ctx, query, accountID).Scan(
		&counts.ActionQueue,
		&counts.ReadingQueue,
		&counts.Filtered,
		&counts.FilteredBorderline,
		&counts.AllInboxes,
	)
	if err != nil {
		return nil, fmt.Errorf("count emails by view for account %s: %w", accountID, err)
	}
	return counts, nil
}

// buildOrderBy returns the ORDER BY clause based on the view.
func buildOrderBy(view string) string {
	switch view {
	case ViewActionQueue:
		// Snoozed-returned first (by return_at DESC), then new (by received_at DESC)
		return "CASE WHEN ss.is_active = FALSE AND ss.return_at IS NOT NULL THEN 0 ELSE 1 END ASC, COALESCE(ss.return_at, e.received_at) DESC, e.id DESC"
	case ViewReadingQueue:
		// Unread first, then partially-read by last_read_at DESC
		return "CASE WHEN e.is_read = FALSE AND e.last_read_at IS NULL THEN 0 WHEN e.is_read = FALSE THEN 1 ELSE 2 END ASC, COALESCE(e.last_read_at, e.received_at) DESC, e.id DESC"
	case ViewFiltered:
		// Borderline first (confidence < 0.80), then standard by received_at DESC
		return "CASE WHEN c.confidence < 0.80 THEN 0 ELSE 1 END ASC, e.received_at DESC, e.id DESC"
	default: // all_inboxes
		return "e.received_at DESC, e.id DESC"
	}
}

// parseCursor decodes the cursor and returns a WHERE clause fragment for keyset pagination.
func parseCursor(view, cursor string, argIdx *int) (string, []any, error) {
	parts, err := models.DecodeCursor(cursor)
	if err != nil {
		return "", nil, err
	}

	// All cursors encode: sort_key, id
	if len(parts) < 2 {
		return "", nil, fmt.Errorf("cursor must have at least 2 parts")
	}

	sortKey := parts[0]
	cursorID := parts[1]

	*argIdx++
	sortArg := fmt.Sprintf("$%d", *argIdx)
	*argIdx++
	idArg := fmt.Sprintf("$%d", *argIdx)

	switch view {
	case ViewActionQueue:
		// Sort key is the composite sort timestamp
		return fmt.Sprintf("(COALESCE(ss.return_at, e.received_at), e.id) < (%s, %s)", sortArg, idArg),
			[]any{sortKey, cursorID}, nil
	case ViewReadingQueue:
		return fmt.Sprintf("(COALESCE(e.last_read_at, e.received_at), e.id) < (%s, %s)", sortArg, idArg),
			[]any{sortKey, cursorID}, nil
	case ViewFiltered:
		return fmt.Sprintf("(e.received_at, e.id) < (%s, %s)", sortArg, idArg),
			[]any{sortKey, cursorID}, nil
	default: // all_inboxes
		return fmt.Sprintf("(e.received_at, e.id) < (%s, %s)", sortArg, idArg),
			[]any{sortKey, cursorID}, nil
	}
}

// buildCursor creates an opaque cursor from the last email in the result set.
func buildCursor(view string, email *models.Email) string {
	var sortKey string
	switch view {
	case ViewActionQueue:
		if email.Snooze != nil && !email.Snooze.IsActive {
			sortKey = email.Snooze.ReturnAt.UTC().Format(time.RFC3339Nano)
		} else {
			sortKey = email.ReceivedAt.UTC().Format(time.RFC3339Nano)
		}
	case ViewReadingQueue:
		if email.LastReadAt != nil {
			sortKey = email.LastReadAt.UTC().Format(time.RFC3339Nano)
		} else {
			sortKey = email.ReceivedAt.UTC().Format(time.RFC3339Nano)
		}
	default:
		sortKey = email.ReceivedAt.UTC().Format(time.RFC3339Nano)
	}
	return models.EncodeCursor(sortKey, email.ID)
}

// enrichViewFields computes view-specific fields on an email.
func enrichViewFields(email *models.Email, view string) {
	switch view {
	case ViewFiltered:
		// Compute days_until_expiry (14 - days since received)
		days := 14 - int(time.Since(email.ReceivedAt).Hours()/24)
		if days < 0 {
			days = 0
		}
		email.DaysUntilExpiry = &days
	case ViewReadingQueue:
		// recommendation_count is populated via subquery if needed (done at query level in future)
	}
}

// scanEmail scans a single email row from a QueryRow result.
func scanEmail(row pgx.Row) (*models.Email, error) {
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
		snzID       *string
		snzEmailID  *string
		snzAt       *time.Time
		snzReturn   *time.Time
		snzCount    *int
		snzActive   *bool
	)

	err := row.Scan(
		&email.ID, &email.AccountID, &email.MessageID, &email.ThreadID,
		&email.From.Email, &email.From.Name, &toJSON, &ccJSON,
		&email.Subject, &email.Snippet, &email.ReceivedAt,
		&email.HasAttachments, &email.IsRead, &email.IsArchived, &labelsJSON,
		&email.LastReadAt, &email.ReadProgress,
		&acctColor, &acctName,
		&classValue, &classConf, &classBy, &classReason, &classOverr,
		&snzID, &snzEmailID, &snzAt, &snzReturn, &snzCount, &snzActive,
	)
	if err != nil {
		return nil, err
	}

	return populateEmail(&email, toJSON, ccJSON, labelsJSON, acctColor, acctName,
		classValue, classConf, classBy, classReason, classOverr,
		snzID, snzEmailID, snzAt, snzReturn, snzCount, snzActive)
}

// scanEmailFromRows scans a single email row from a Rows iterator.
func scanEmailFromRows(rows pgx.Rows) (*models.Email, error) {
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
		snzID       *string
		snzEmailID  *string
		snzAt       *time.Time
		snzReturn   *time.Time
		snzCount    *int
		snzActive   *bool
	)

	err := rows.Scan(
		&email.ID, &email.AccountID, &email.MessageID, &email.ThreadID,
		&email.From.Email, &email.From.Name, &toJSON, &ccJSON,
		&email.Subject, &email.Snippet, &email.ReceivedAt,
		&email.HasAttachments, &email.IsRead, &email.IsArchived, &labelsJSON,
		&email.LastReadAt, &email.ReadProgress,
		&acctColor, &acctName,
		&classValue, &classConf, &classBy, &classReason, &classOverr,
		&snzID, &snzEmailID, &snzAt, &snzReturn, &snzCount, &snzActive,
	)
	if err != nil {
		return nil, err
	}

	return populateEmail(&email, toJSON, ccJSON, labelsJSON, acctColor, acctName,
		classValue, classConf, classBy, classReason, classOverr,
		snzID, snzEmailID, snzAt, snzReturn, snzCount, snzActive)
}

// scanEmailWithBody scans a row that includes html_body and text_body columns.
func scanEmailWithBody(row pgx.Row, htmlBody, textBody *string) (*models.Email, error) {
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
		snzID       *string
		snzEmailID  *string
		snzAt       *time.Time
		snzReturn   *time.Time
		snzCount    *int
		snzActive   *bool
	)

	err := row.Scan(
		&email.ID, &email.AccountID, &email.MessageID, &email.ThreadID,
		&email.From.Email, &email.From.Name, &toJSON, &ccJSON,
		&email.Subject, &email.Snippet, &email.ReceivedAt,
		&email.HasAttachments, &email.IsRead, &email.IsArchived, &labelsJSON,
		&email.LastReadAt, &email.ReadProgress,
		&acctColor, &acctName,
		&classValue, &classConf, &classBy, &classReason, &classOverr,
		&snzID, &snzEmailID, &snzAt, &snzReturn, &snzCount, &snzActive,
		htmlBody, textBody,
	)
	if err != nil {
		return nil, err
	}

	return populateEmail(&email, toJSON, ccJSON, labelsJSON, acctColor, acctName,
		classValue, classConf, classBy, classReason, classOverr,
		snzID, snzEmailID, snzAt, snzReturn, snzCount, snzActive)
}

// populateEmail hydrates the email struct from scanned nullable values.
func populateEmail(
	email *models.Email,
	toJSON, ccJSON, labelsJSON []byte,
	acctColor, acctName string,
	classValue *string, classConf *float64, classBy *string, classReason *string, classOverr *bool,
	snzID *string, snzEmailID *string, snzAt *time.Time, snzReturn *time.Time, snzCount *int, snzActive *bool,
) (*models.Email, error) {
	// Unmarshal JSONB fields
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

	// Classification
	if classValue != nil {
		email.Classification = &models.Classification{
			Classification: *classValue,
			Confidence:     derefFloat(classConf),
			ClassifiedBy:   derefStr(classBy),
			Reason:         derefStr(classReason),
			IsOverridden:   derefBool(classOverr),
		}
	}

	// Snooze state
	if snzID != nil {
		email.Snooze = &models.SnoozeState{
			ID:          *snzID,
			EmailID:     derefStr(snzEmailID),
			SnoozedAt:   derefTime(snzAt),
			ReturnAt:    derefTime(snzReturn),
			SnoozeCount: derefInt(snzCount),
			IsActive:    derefBool(snzActive),
		}
	}

	return email, nil
}

// Helper functions for dereferencing nullable scan values.

func derefStr(p *string) string {
	if p != nil {
		return *p
	}
	return ""
}

func derefFloat(p *float64) float64 {
	if p != nil {
		return *p
	}
	return 0
}

func derefBool(p *bool) bool {
	if p != nil {
		return *p
	}
	return false
}

func derefTime(p *time.Time) time.Time {
	if p != nil {
		return *p
	}
	return time.Time{}
}

func derefInt(p *int) int {
	if p != nil {
		return *p
	}
	return 0
}
