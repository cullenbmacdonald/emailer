package storage

import (
	"context"
	"os"
	"testing"
	"testing/fstest"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func TestListMigrationFiles(t *testing.T) {
	files, err := listMigrationFiles(embeddedMigrations)
	if err != nil {
		t.Fatalf("listMigrationFiles() error: %v", err)
	}

	if len(files) == 0 {
		t.Fatal("expected at least one migration file")
	}

	if files[0] != "000_extensions.sql" {
		t.Errorf("expected first migration to be 000_extensions.sql, got %s", files[0])
	}

	// Verify files are sorted
	for i := 1; i < len(files); i++ {
		if files[i] < files[i-1] {
			t.Errorf("migration files not sorted: %s came after %s", files[i], files[i-1])
		}
	}
}

func TestListMigrationFilesSort(t *testing.T) {
	fs := fstest.MapFS{
		"migrations/003_third.sql":  {Data: []byte("SELECT 3;")},
		"migrations/001_first.sql":  {Data: []byte("SELECT 1;")},
		"migrations/002_second.sql": {Data: []byte("SELECT 2;")},
	}

	files, err := listMigrationFiles(fs)
	if err != nil {
		t.Fatalf("listMigrationFiles() error: %v", err)
	}

	expected := []string{"001_first.sql", "002_second.sql", "003_third.sql"}
	if len(files) != len(expected) {
		t.Fatalf("expected %d files, got %d", len(expected), len(files))
	}
	for i, want := range expected {
		if files[i] != want {
			t.Errorf("files[%d] = %s, want %s", i, files[i], want)
		}
	}
}

func TestListMigrationFilesSkipsNonSQL(t *testing.T) {
	fs := fstest.MapFS{
		"migrations/001_first.sql":  {Data: []byte("SELECT 1;")},
		"migrations/002_second.sql": {Data: []byte("SELECT 2;")},
		"migrations/README.md":      {Data: []byte("# Migrations")},
		"migrations/.gitkeep":       {Data: []byte("")},
	}

	files, err := listMigrationFiles(fs)
	if err != nil {
		t.Fatalf("listMigrationFiles() error: %v", err)
	}

	if len(files) != 2 {
		t.Errorf("expected 2 SQL files, got %d: %v", len(files), files)
	}
}

// --- Integration tests (require a running PostgreSQL) ---

func getTestDSN(t *testing.T) string {
	t.Helper()
	if testing.Short() {
		t.Skip("skipping integration test in short mode")
	}

	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://emailer:emailer@localhost:5432/emailer?sslmode=disable"
	}
	return dsn
}

func getTestPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := getTestDSN(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pool, err := NewDB(ctx, DefaultDBConfig(dsn))
	if err != nil {
		t.Skipf("skipping: cannot connect to PostgreSQL: %v", err)
	}

	if err := Ping(ctx, pool); err != nil {
		pool.Close()
		t.Skipf("skipping: PostgreSQL ping failed: %v", err)
	}

	t.Cleanup(func() { pool.Close() })
	return pool
}

func cleanupMigrations(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	_, _ = pool.Exec(ctx, "DROP TABLE IF EXISTS schema_migrations CASCADE")
	_, _ = pool.Exec(ctx, "DROP TABLE IF EXISTS _test_table CASCADE")
}

func TestIntegrationNewDBAndPing(t *testing.T) {
	pool := getTestPool(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := Ping(ctx, pool); err != nil {
		t.Fatalf("Ping() error: %v", err)
	}
}

func TestIntegrationRunMigrations(t *testing.T) {
	pool := getTestPool(t)
	cleanupMigrations(t, pool)
	t.Cleanup(func() { cleanupMigrations(t, pool) })

	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations() error: %v", err)
	}

	// Verify schema_migrations table has the migration recorded
	var filename string
	err := pool.QueryRow(ctx,
		"SELECT filename FROM schema_migrations WHERE filename = $1",
		"000_extensions.sql",
	).Scan(&filename)
	if err != nil {
		t.Fatalf("querying for 000_extensions.sql: %v", err)
	}
}

func TestIntegrationRunMigrationsIdempotent(t *testing.T) {
	pool := getTestPool(t)
	cleanupMigrations(t, pool)
	t.Cleanup(func() { cleanupMigrations(t, pool) })

	ctx := context.Background()

	// Run twice — second should be a no-op
	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("first RunMigrations() error: %v", err)
	}
	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("second RunMigrations() error: %v", err)
	}

	var count int
	err := pool.QueryRow(ctx, "SELECT COUNT(*) FROM schema_migrations").Scan(&count)
	if err != nil {
		t.Fatalf("querying schema_migrations: %v", err)
	}

	files, _ := listMigrationFiles(embeddedMigrations)
	if count != len(files) {
		t.Errorf("expected %d migrations recorded, got %d", len(files), count)
	}
}

func TestIntegrationMigrationFailureRollback(t *testing.T) {
	pool := getTestPool(t)
	cleanupMigrations(t, pool)
	t.Cleanup(func() { cleanupMigrations(t, pool) })

	ctx := context.Background()

	// Use a test FS with one good migration and one bad migration
	testFS := fstest.MapFS{
		"migrations/001_good.sql": {Data: []byte("CREATE TABLE _test_table (id SERIAL PRIMARY KEY);")},
		"migrations/002_bad.sql":  {Data: []byte("THIS IS NOT VALID SQL AT ALL;")},
	}

	err := runMigrations(ctx, pool, testFS)
	if err == nil {
		t.Fatal("expected error from bad migration, got nil")
	}

	// Error should mention the bad file
	if !containsSubstr(err.Error(), "002_bad.sql") {
		t.Errorf("expected error to mention 002_bad.sql, got: %s", err)
	}

	// The good migration SHOULD have been applied (it was committed before the bad one)
	var goodCount int
	qErr := pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM schema_migrations WHERE filename = $1",
		"001_good.sql",
	).Scan(&goodCount)
	if qErr != nil {
		t.Fatalf("querying schema_migrations: %v", qErr)
	}
	if goodCount != 1 {
		t.Error("expected good migration to be recorded")
	}

	// The bad migration should NOT have been recorded
	var badCount int
	qErr = pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM schema_migrations WHERE filename = $1",
		"002_bad.sql",
	).Scan(&badCount)
	if qErr != nil {
		t.Fatalf("querying schema_migrations: %v", qErr)
	}
	if badCount != 0 {
		t.Error("expected failed migration NOT to be recorded")
	}

	// The _test_table from the good migration should exist
	var exists bool
	err = pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = '_test_table')",
	).Scan(&exists)
	if err != nil {
		t.Fatalf("querying information_schema: %v", err)
	}
	if !exists {
		t.Error("expected _test_table to exist from successful migration")
	}
}

func TestIntegrationMigrationOrder(t *testing.T) {
	pool := getTestPool(t)
	cleanupMigrations(t, pool)
	t.Cleanup(func() { cleanupMigrations(t, pool) })

	ctx := context.Background()

	// Migration 002 depends on the table created by 001
	testFS := fstest.MapFS{
		"migrations/001_create.sql": {Data: []byte("CREATE TABLE _test_table (id SERIAL PRIMARY KEY);")},
		"migrations/002_alter.sql":  {Data: []byte("ALTER TABLE _test_table ADD COLUMN name TEXT;")},
	}

	if err := runMigrations(ctx, pool, testFS); err != nil {
		t.Fatalf("runMigrations() error: %v", err)
	}

	// Both migrations should be recorded
	var count int
	err := pool.QueryRow(ctx, "SELECT COUNT(*) FROM schema_migrations").Scan(&count)
	if err != nil {
		t.Fatalf("querying schema_migrations: %v", err)
	}
	if count != 2 {
		t.Errorf("expected 2 migrations recorded, got %d", count)
	}

	// Verify the column was added
	var exists bool
	err = pool.QueryRow(ctx,
		`SELECT EXISTS(
			SELECT 1 FROM information_schema.columns
			WHERE table_name = '_test_table' AND column_name = 'name'
		)`,
	).Scan(&exists)
	if err != nil {
		t.Fatalf("querying information_schema: %v", err)
	}
	if !exists {
		t.Error("expected 'name' column to exist on _test_table")
	}
}

func containsSubstr(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
