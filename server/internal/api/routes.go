package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

// routes builds the chi router with all middleware and route registrations.
func (s *Server) routes(authToken string, corsOrigins []string) *chi.Mux {
	r := chi.NewRouter()

	// Global middleware (applied to all routes)
	r.Use(chimiddleware.RealIP)
	r.Use(RequestID)
	r.Use(LoggingMiddleware)
	r.Use(chimiddleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   corsOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Health endpoint (no auth required)
	r.Get("/health", s.handleHealth())

	// API v1 routes (auth required)
	r.Route("/api/v1", func(r chi.Router) {
		r.Use(AuthMiddleware(authToken))

		// Email endpoints
		if s.emails != nil {
			r.Get("/emails", s.handleListEmails())
			r.Get("/emails/{id}", s.handleGetEmail())
			r.Patch("/emails/{id}", s.handleUpdateEmail())
			r.Delete("/emails/{id}", s.handleDeleteEmail())
			r.Post("/emails/{id}/reclassify", s.handleReclassify())
			r.Post("/emails/{id}/snooze", s.handleSnooze())
			r.Delete("/emails/{id}/snooze", s.handleUnsnooze())
			r.Get("/emails/{id}/attachments/{attachment_id}", s.handleDownloadAttachment())
		}

		// Account endpoints
		if s.accounts != nil {
			r.Get("/accounts", s.handleListAccounts())
			r.Get("/accounts/{id}", s.handleGetAccount())
		}

		// Catch-all for unregistered API routes (returns 404 after auth check).
		// This ensures auth middleware runs even for non-existent endpoints.
		r.HandleFunc("/*", func(w http.ResponseWriter, r *http.Request) {
			WriteError(w, http.StatusNotFound, "not_found", "endpoint not found")
		})
	})

	return r
}
