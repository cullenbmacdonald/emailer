// Package api implements the HTTP server, routes, middleware, and handlers.
package api

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// BuildInfo holds version information injected at compile time.
type BuildInfo struct {
	Version   string
	Commit    string
	BuildTime string
}

// Server wraps the HTTP server and its dependencies.
type Server struct {
	httpServer *http.Server
	pool       *pgxpool.Pool
	buildInfo  BuildInfo
	startTime  time.Time

	emails          EmailStore
	classifications ClassificationStore
	snoozes         SnoozeStore
	accounts        AccountStore
}

// ServerDeps holds optional dependencies for the server.
// If nil, handlers that need them will return 501.
type ServerDeps struct {
	Emails          EmailStore
	Classifications ClassificationStore
	Snoozes         SnoozeStore
	Accounts        AccountStore
}

// NewServer creates a new HTTP server with all routes and middleware wired up.
func NewServer(addr string, pool *pgxpool.Pool, authToken string, corsOrigins []string, info BuildInfo, deps ...ServerDeps) *Server {
	s := &Server{
		pool:      pool,
		buildInfo: info,
		startTime: time.Now(),
	}

	if len(deps) > 0 {
		d := deps[0]
		s.emails = d.Emails
		s.classifications = d.Classifications
		s.snoozes = d.Snoozes
		s.accounts = d.Accounts
	}

	router := s.routes(authToken, corsOrigins)

	s.httpServer = &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	return s
}

// Start begins listening and serving HTTP requests.
// It returns immediately; the server runs in the background.
// Use the returned error channel to detect startup failures.
func (s *Server) Start() <-chan error {
	errCh := make(chan error, 1)
	go func() {
		log.Info().Str("address", s.httpServer.Addr).Msg("server listening")
		if err := s.httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errCh <- err
		}
	}()
	return errCh
}

// Shutdown gracefully stops the server with the given context deadline.
func (s *Server) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}
