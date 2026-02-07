package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// SenderStats represents sender behavior statistics.
type SenderStats struct {
	ID              string
	SenderEmail     string
	TotalReceived   int
	TotalReplied    int
	LastReceivedAt  *time.Time
	LastRepliedAt   *time.Time
	AvgReplyTime    *float64
	MostCommonClass *string
}

// SenderStatsStore provides operations for the sender_stats table.
type SenderStatsStore struct {
	pool *pgxpool.Pool
}

// NewSenderStatsStore creates a new SenderStatsStore.
func NewSenderStatsStore(pool *pgxpool.Pool) *SenderStatsStore {
	return &SenderStatsStore{pool: pool}
}

// GetSenderStats returns stats for a sender email address.
func (s *SenderStatsStore) GetSenderStats(ctx context.Context, email string) (*SenderStats, error) {
	query := `
		SELECT id, sender_email, total_received, total_replied,
			   last_received_at, last_replied_at, avg_reply_time, most_common_class
		FROM sender_stats
		WHERE sender_email = $1`

	var stats SenderStats
	err := s.pool.QueryRow(ctx, query, email).Scan(
		&stats.ID, &stats.SenderEmail, &stats.TotalReceived, &stats.TotalReplied,
		&stats.LastReceivedAt, &stats.LastRepliedAt, &stats.AvgReplyTime, &stats.MostCommonClass,
	)
	if err != nil {
		return nil, fmt.Errorf("get sender stats for %s: %w", email, err)
	}
	return &stats, nil
}

// UpsertSenderStats inserts or updates sender statistics.
func (s *SenderStatsStore) UpsertSenderStats(ctx context.Context, stats *SenderStats) error {
	query := `
		INSERT INTO sender_stats (
			sender_email, total_received, total_replied,
			last_received_at, last_replied_at, avg_reply_time, most_common_class
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (sender_email) DO UPDATE SET
			total_received = EXCLUDED.total_received,
			total_replied = EXCLUDED.total_replied,
			last_received_at = EXCLUDED.last_received_at,
			last_replied_at = EXCLUDED.last_replied_at,
			avg_reply_time = EXCLUDED.avg_reply_time,
			most_common_class = EXCLUDED.most_common_class,
			updated_at = NOW()`

	_, err := s.pool.Exec(ctx, query,
		stats.SenderEmail, stats.TotalReceived, stats.TotalReplied,
		stats.LastReceivedAt, stats.LastRepliedAt, stats.AvgReplyTime, stats.MostCommonClass,
	)
	if err != nil {
		return fmt.Errorf("upsert sender stats for %s: %w", stats.SenderEmail, err)
	}
	return nil
}
