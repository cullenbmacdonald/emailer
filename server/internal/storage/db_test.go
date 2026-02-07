package storage

import (
	"testing"
	"time"
)

func TestDefaultDBConfig(t *testing.T) {
	dsn := "postgres://user:pass@localhost:5432/testdb"
	cfg := DefaultDBConfig(dsn)

	if cfg.DSN != dsn {
		t.Errorf("expected DSN %q, got %q", dsn, cfg.DSN)
	}
	if cfg.MaxConns != 10 {
		t.Errorf("expected MaxConns 10, got %d", cfg.MaxConns)
	}
	if cfg.MinConns != 2 {
		t.Errorf("expected MinConns 2, got %d", cfg.MinConns)
	}
	if cfg.MaxConnIdleTime != 5*time.Minute {
		t.Errorf("expected MaxConnIdleTime 5m, got %v", cfg.MaxConnIdleTime)
	}
	if cfg.MaxConnLifetime != 1*time.Hour {
		t.Errorf("expected MaxConnLifetime 1h, got %v", cfg.MaxConnLifetime)
	}
}
