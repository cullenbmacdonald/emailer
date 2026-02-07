package main

import (
	"context"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/config"
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

	// Set up HTTP server (placeholder until S-1.7 adds chi router + handlers)
	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = fmt.Fprintf(w, `{"status":"healthy","version":%q,"commit":%q}`, version, commitHash)
	})

	srv := &http.Server{
		Addr:         cfg.Address(),
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	errCh := make(chan error, 1)
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
		}
	}()

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

	// Graceful shutdown with 30-second timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	shutdownErr := srv.Shutdown(shutdownCtx)
	shutdownCancel()

	if shutdownErr != nil {
		log.Error().Err(shutdownErr).Msg("shutdown error")
		os.Exit(1)
	}

	log.Info().Msg("server stopped")
}
