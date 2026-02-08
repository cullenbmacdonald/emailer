package digest

import (
	"context"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PgDataSource implements DataSource using PostgreSQL queries.
type PgDataSource struct {
	pool *pgxpool.Pool
}

// NewPgDataSource creates a new PostgreSQL-backed data source.
func NewPgDataSource(pool *pgxpool.Pool) *PgDataSource {
	return &PgDataSource{pool: pool}
}

// ActionQueueSummary returns the count and per-account breakdown of unarchived action_required emails.
func (ds *PgDataSource) ActionQueueSummary(ctx context.Context) (int, []models.AccountCount, error) {
	// Total count.
	var total int
	err := ds.pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		WHERE c.classification = 'action_required' AND e.is_archived = FALSE
	`).Scan(&total)
	if err != nil {
		return 0, nil, fmt.Errorf("action queue total: %w", err)
	}

	// Per-account breakdown.
	rows, err := ds.pool.Query(ctx, `
		SELECT a.id, a.name, a.color, COUNT(*) AS cnt
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		JOIN accounts a ON a.id = e.account_id
		WHERE c.classification = 'action_required' AND e.is_archived = FALSE
		GROUP BY a.id, a.name, a.color
		ORDER BY cnt DESC
	`)
	if err != nil {
		return total, nil, fmt.Errorf("action queue breakdown: %w", err)
	}
	defer rows.Close()

	var breakdown []models.AccountCount
	for rows.Next() {
		var ac models.AccountCount
		if err := rows.Scan(&ac.AccountID, &ac.AccountName, &ac.AccountColor, &ac.Count); err != nil {
			return total, nil, fmt.Errorf("scan account count: %w", err)
		}
		breakdown = append(breakdown, ac)
	}
	return total, breakdown, rows.Err()
}

// ReturningToday returns snoozes that return on the given date.
func (ds *PgDataSource) ReturningToday(ctx context.Context, date time.Time) ([]DigestSnoozeItem, error) {
	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	endOfDay := startOfDay.AddDate(0, 0, 1)

	rows, err := ds.pool.Query(ctx, `
		SELECT ss.email_id, e.subject, e.from_name, ss.return_at
		FROM snooze_states ss
		JOIN emails e ON e.id = ss.email_id
		WHERE ss.is_active = TRUE AND ss.return_at >= $1 AND ss.return_at < $2
		ORDER BY ss.return_at ASC
	`, startOfDay, endOfDay)
	if err != nil {
		return nil, fmt.Errorf("returning today: %w", err)
	}
	defer rows.Close()

	var items []DigestSnoozeItem
	for rows.Next() {
		var item DigestSnoozeItem
		if err := rows.Scan(&item.EmailID, &item.Subject, &item.From, &item.ReturnAt); err != nil {
			return nil, fmt.Errorf("scan snooze item: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// ReadingQueueCount returns the count of unarchived newsletter emails.
func (ds *PgDataSource) ReadingQueueCount(ctx context.Context) (int, error) {
	var count int
	err := ds.pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		WHERE c.classification = 'newsletter' AND e.is_archived = FALSE
	`).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("reading queue count: %w", err)
	}
	return count, nil
}

// BorderlineFiltered returns filtered emails near the confidence threshold.
func (ds *PgDataSource) BorderlineFiltered(ctx context.Context, limit int, threshold float64) ([]DigestBorderlineItem, error) {
	rows, err := ds.pool.Query(ctx, `
		SELECT e.id, e.subject, e.from_name, c.confidence, COALESCE(c.reason, '')
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		WHERE c.classification = 'filtered' AND c.confidence < $1
		ORDER BY c.confidence DESC
		LIMIT $2
	`, threshold, limit)
	if err != nil {
		return nil, fmt.Errorf("borderline filtered: %w", err)
	}
	defer rows.Close()

	var items []DigestBorderlineItem
	for rows.Next() {
		var item DigestBorderlineItem
		if err := rows.Scan(&item.EmailID, &item.Subject, &item.From, &item.Confidence, &item.Reason); err != nil {
			return nil, fmt.Errorf("scan borderline item: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// NotableTransactional returns transactional emails with shipping keywords or large charges.
func (ds *PgDataSource) NotableTransactional(ctx context.Context, since time.Time) ([]DigestTransactionalItem, error) {
	rows, err := ds.pool.Query(ctx, `
		SELECT e.id, e.subject, e.from_name
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		WHERE c.classification = 'transactional' AND e.received_at >= $1
		ORDER BY e.received_at DESC
	`, since)
	if err != nil {
		return nil, fmt.Errorf("notable transactional: %w", err)
	}
	defer rows.Close()

	var items []DigestTransactionalItem
	for rows.Next() {
		var emailID, subject, from string
		if err := rows.Scan(&emailID, &subject, &from); err != nil {
			return nil, fmt.Errorf("scan transactional: %w", err)
		}

		if IsShippingSubject(subject) {
			items = append(items, DigestTransactionalItem{
				EmailID:       emailID,
				Subject:       subject,
				From:          from,
				HighlightType: "shipping",
				DisplayText:   subject,
			})
		} else if amount := ExtractLargeCharge(subject); amount > 0 {
			items = append(items, DigestTransactionalItem{
				EmailID:       emailID,
				Subject:       subject,
				From:          from,
				HighlightType: "large_charge",
				DisplayText:   fmt.Sprintf("$%.2f", amount),
			})
		}
	}
	return items, rows.Err()
}

// TodayStats returns counts of archived and sent emails since the given time.
func (ds *PgDataSource) TodayStats(ctx context.Context, since time.Time) (int, int, error) {
	var archived int
	err := ds.pool.QueryRow(ctx, `
		SELECT COUNT(*)
		FROM emails
		WHERE is_archived = TRUE AND updated_at >= $1
	`, since).Scan(&archived)
	if err != nil {
		return 0, 0, fmt.Errorf("today archived count: %w", err)
	}

	// Sent count: we don't have a sent emails table yet, so return 0.
	// This will be populated when SMTP sending tracks outbound messages.
	return archived, 0, nil
}

// NewslettersToday returns newsletters received since the given time.
func (ds *PgDataSource) NewslettersToday(ctx context.Context, since time.Time) ([]DigestNewsletterItem, error) {
	rows, err := ds.pool.Query(ctx, `
		SELECT e.id, COALESCE(e.from_name, e.from_address), e.subject
		FROM emails e
		JOIN classifications c ON c.email_id = e.id
		WHERE c.classification = 'newsletter' AND e.received_at >= $1
		ORDER BY e.received_at DESC
	`, since)
	if err != nil {
		return nil, fmt.Errorf("newsletters today: %w", err)
	}
	defer rows.Close()

	var items []DigestNewsletterItem
	for rows.Next() {
		var item DigestNewsletterItem
		if err := rows.Scan(&item.EmailID, &item.NewsletterName, &item.Subject); err != nil {
			return nil, fmt.Errorf("scan newsletter item: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// SnoozeNudges returns emails snoozed minSnoozeCount or more times.
func (ds *PgDataSource) SnoozeNudges(ctx context.Context, minSnoozeCount int) ([]DigestSnoozeNudge, error) {
	rows, err := ds.pool.Query(ctx, `
		SELECT ss.email_id, e.subject, e.from_name, ss.snooze_count,
		       EXTRACT(DAY FROM NOW() - MIN(ss.snoozed_at))::int AS days_since_first
		FROM snooze_states ss
		JOIN emails e ON e.id = ss.email_id
		WHERE ss.snooze_count >= $1
		GROUP BY ss.email_id, e.subject, e.from_name, ss.snooze_count
		ORDER BY ss.snooze_count DESC
	`, minSnoozeCount)
	if err != nil {
		return nil, fmt.Errorf("snooze nudges: %w", err)
	}
	defer rows.Close()

	var items []DigestSnoozeNudge
	for rows.Next() {
		var item DigestSnoozeNudge
		if err := rows.Scan(&item.EmailID, &item.Subject, &item.From, &item.SnoozeCount, &item.DaysSinceFirstSnooze); err != nil {
			return nil, fmt.Errorf("scan snooze nudge: %w", err)
		}
		items = append(items, item)
	}
	return items, rows.Err()
}
