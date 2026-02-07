// Package storage handles database connectivity and schema migrations.
package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// DBConfig holds connection pool configuration.
type DBConfig struct {
	DSN             string
	MaxConns        int32
	MinConns        int32
	MaxConnIdleTime time.Duration
	MaxConnLifetime time.Duration
}

// DefaultDBConfig returns pool settings with sensible defaults.
func DefaultDBConfig(dsn string) DBConfig {
	return DBConfig{
		DSN:             dsn,
		MaxConns:        10,
		MinConns:        2,
		MaxConnIdleTime: 5 * time.Minute,
		MaxConnLifetime: 1 * time.Hour,
	}
}

// NewDB creates a new pgxpool.Pool from the given configuration.
func NewDB(ctx context.Context, cfg DBConfig) (*pgxpool.Pool, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("parsing database DSN: %w", err)
	}

	poolCfg.MaxConns = cfg.MaxConns
	poolCfg.MinConns = cfg.MinConns
	poolCfg.MaxConnIdleTime = cfg.MaxConnIdleTime
	poolCfg.MaxConnLifetime = cfg.MaxConnLifetime

	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("creating connection pool: %w", err)
	}

	return pool, nil
}

// Ping verifies database connectivity by executing a ping on the pool.
func Ping(ctx context.Context, pool *pgxpool.Pool) error {
	if err := pool.Ping(ctx); err != nil {
		return fmt.Errorf("database ping failed: %w", err)
	}
	return nil
}
