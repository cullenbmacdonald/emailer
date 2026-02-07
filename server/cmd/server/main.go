package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/api"
	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/classifier"
	imapmanager "github.com/cullenbmacdonald/emailer/internal/imap"
	"github.com/cullenbmacdonald/emailer/internal/storage"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Build info, injected via ldflags at compile time.
var (
	version    = "dev"
	commitHash = "unknown"
	buildTime  = "unknown"
)

func main() {
	configPath := flag.String("config", "config.yaml", "path to configuration file")
	flag.Parse()

	args := flag.Args()

	cfg, err := config.Load(*configPath)
	if err != nil {
		// If config file doesn't exist and no explicit path was given,
		// try loading from env vars only
		if flag.Lookup("config").DefValue == *configPath {
			cfg, err = config.Load("")
			if err != nil {
				fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
				os.Exit(1)
			}
		} else {
			fmt.Fprintf(os.Stderr, "failed to load config: %v\n", err)
			os.Exit(1)
		}
	}

	// Handle subcommands.
	if len(args) >= 2 && args[0] == "token-auth" {
		runTokenAuth(cfg, args[1])
		return
	}
	if len(args) >= 1 && args[0] == "token-auth" {
		fmt.Fprintf(os.Stderr, "usage: server token-auth <account-id>\n")
		os.Exit(1)
	}

	// Set up structured logging
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	level, err := zerolog.ParseLevel(cfg.Logging.Level)
	if err != nil {
		level = zerolog.InfoLevel
	}
	zerolog.SetGlobalLevel(level)
	log.Logger = zerolog.New(os.Stdout).With().Timestamp().Logger()

	log.Info().
		Str("address", cfg.Address()).
		Str("version", version).
		Str("commit", commitHash).
		Str("build_time", buildTime).
		Msg("server starting")

	// Connect to database (if DSN is configured)
	var pool *pgxpool.Pool
	if cfg.Database.DSN != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		dbCfg := storage.DBConfig{
			DSN:             cfg.Database.DSN,
			MaxConns:        cfg.Database.MaxConns,
			MinConns:        cfg.Database.MinConns,
			MaxConnIdleTime: parseDuration(cfg.Database.MaxConnIdle, 5*time.Minute),
			MaxConnLifetime: parseDuration(cfg.Database.MaxConnLife, 1*time.Hour),
		}
		p, dbErr := storage.NewDB(ctx, dbCfg)
		cancel()
		if dbErr != nil {
			log.Warn().Err(dbErr).Msg("failed to connect to database, starting without DB")
		} else {
			pool = p

			// Run migrations
			if migrateErr := storage.RunMigrations(context.Background(), pool); migrateErr != nil {
				log.Error().Err(migrateErr).Msg("failed to run migrations")
			} else {
				log.Info().Msg("database migrations applied")
			}
		}
	}

	// Upsert configured accounts into the database.
	if pool != nil && len(cfg.Accounts) > 0 {
		for _, acct := range cfg.Accounts {
			_, upsertErr := pool.Exec(context.Background(),
				`INSERT INTO accounts (id, name, email, provider, account_type, color)
				 VALUES ($1, $2, $3, $4, $5, $6)
				 ON CONFLICT (id) DO UPDATE SET
				   name = EXCLUDED.name, email = EXCLUDED.email,
				   provider = EXCLUDED.provider, account_type = EXCLUDED.account_type,
				   color = EXCLUDED.color, updated_at = NOW()`,
				acct.ID, acct.Name, acct.Email, acct.Provider, acct.AccountType, acct.Color)
			if upsertErr != nil {
				log.Error().Err(upsertErr).Str("account", acct.Name).Msg("failed to upsert account")
			}
		}
		log.Info().Int("accounts", len(cfg.Accounts)).Msg("accounts synced to database")
	}

	// Create and start IMAP manager (if accounts are configured and DB is available).
	var imapMgr *imapmanager.Manager
	if len(cfg.Accounts) > 0 {
		mgr, imapErr := imapmanager.NewManager(cfg.Accounts, log.Logger)
		if imapErr != nil {
			log.Error().Err(imapErr).Msg("failed to create IMAP manager")
		} else {
			imapMgr = mgr

			// Wire up the email syncer if we have a database connection.
			if pool != nil {
				syncer := imapmanager.NewEmailSyncer(pool, log.Logger)
				// Wire up classification pipeline (rules + features, no LLM for now).
				pipeline := classifier.NewPipeline(nil, nil, nil, log.Logger)
				syncer.SetClassifier(pipeline)
				imapMgr.SetSyncer(syncer)
			}

			imapMgr.Start(context.Background())
			log.Info().Int("accounts", len(cfg.Accounts)).Msg("IMAP manager started")
		}
	}

	// Create and start HTTP server
	srv := api.NewServer(cfg.Address(), pool, cfg.API.AuthToken, cfg.API.CORSOrig, api.BuildInfo{
		Version:   version,
		Commit:    commitHash,
		BuildTime: buildTime,
	})

	errCh := srv.Start()

	log.Info().
		Str("address", cfg.Address()).
		Msg("server started")

	// Wait for interrupt signal or server error
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		log.Info().Str("signal", sig.String()).Msg("received signal, shutting down")
	case err := <-errCh:
		log.Error().Err(err).Msg("server error")
	}

	// Stop IMAP manager first.
	if imapMgr != nil {
		imapMgr.Stop()
	}

	// Graceful shutdown with 30-second timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	shutdownErr := srv.Shutdown(shutdownCtx)
	shutdownCancel()

	if pool != nil {
		pool.Close()
	}

	if shutdownErr != nil {
		log.Error().Err(shutdownErr).Msg("shutdown error")
		os.Exit(1)
	}

	log.Info().Msg("server stopped")
}

// parseDuration parses a duration string, returning the fallback on error.
func parseDuration(s string, fallback time.Duration) time.Duration {
	d, err := time.ParseDuration(s)
	if err != nil {
		return fallback
	}
	return d
}
