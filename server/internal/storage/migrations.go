package storage

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var embeddedMigrations embed.FS

// migrationFS is the interface needed by the migration runner.
// embed.FS and testing/fstest.MapFS both satisfy this.
type migrationFS interface {
	fs.ReadDirFS
	fs.ReadFileFS
}

// RunMigrations applies all pending SQL migrations in filename order.
// It creates the schema_migrations tracking table if it does not exist,
// skips already-applied migrations, and rolls back any migration that fails.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	return runMigrations(ctx, pool, embeddedMigrations)
}

// runMigrations is the internal implementation, accepting a filesystem for testability.
func runMigrations(ctx context.Context, pool *pgxpool.Pool, mfs migrationFS) error {
	if err := ensureMigrationsTable(ctx, pool); err != nil {
		return err
	}

	files, err := listMigrationFiles(mfs)
	if err != nil {
		return err
	}

	for _, filename := range files {
		applied, err := isMigrationApplied(ctx, pool, filename)
		if err != nil {
			return err
		}
		if applied {
			continue
		}

		if err := applyMigration(ctx, pool, mfs, filename); err != nil {
			return err
		}
	}

	return nil
}

// ensureMigrationsTable creates the schema_migrations table if it doesn't exist.
func ensureMigrationsTable(ctx context.Context, pool *pgxpool.Pool) error {
	query := `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			filename    TEXT PRIMARY KEY,
			applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`
	if _, err := pool.Exec(ctx, query); err != nil {
		return fmt.Errorf("creating schema_migrations table: %w", err)
	}
	return nil
}

// listMigrationFiles returns .sql filenames from the migrations/ directory, sorted alphabetically.
func listMigrationFiles(mfs migrationFS) ([]string, error) {
	entries, err := mfs.ReadDir("migrations")
	if err != nil {
		return nil, fmt.Errorf("reading migrations directory: %w", err)
	}

	files := make([]string, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		files = append(files, entry.Name())
	}

	sort.Strings(files)
	return files, nil
}

// isMigrationApplied checks if a migration has already been recorded.
func isMigrationApplied(ctx context.Context, pool *pgxpool.Pool, filename string) (bool, error) {
	var exists bool
	err := pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE filename = $1)",
		filename,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking migration %s: %w", filename, err)
	}
	return exists, nil
}

// applyMigration runs a single migration inside a transaction and records it.
func applyMigration(ctx context.Context, pool *pgxpool.Pool, mfs migrationFS, filename string) error {
	content, err := mfs.ReadFile("migrations/" + filename)
	if err != nil {
		return fmt.Errorf("reading migration %s: %w", filename, err)
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("beginning transaction for migration %s: %w", filename, err)
	}
	defer tx.Rollback(ctx) //nolint:errcheck // rollback on committed tx is harmless

	if _, err := tx.Exec(ctx, string(content)); err != nil {
		return fmt.Errorf("executing migration %s: %w", filename, err)
	}

	if _, err := tx.Exec(ctx,
		"INSERT INTO schema_migrations (filename) VALUES ($1)",
		filename,
	); err != nil {
		return fmt.Errorf("recording migration %s: %w", filename, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("committing migration %s: %w", filename, err)
	}

	return nil
}
