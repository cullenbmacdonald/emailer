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

	// WebSocket endpoint (authenticates via query param, not Bearer header)
	r.Get("/api/v1/ws", s.handleWebSocket(authToken))

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

		// Search endpoint
		if s.search != nil {
			r.Get("/search", s.handleSearchEmails())
		}

		// Compose endpoints
		if s.compose != nil {
			r.Get("/compose/drafts", s.handleListDrafts())
			r.Post("/compose/drafts", s.handleCreateDraft())
			r.Put("/compose/drafts/{id}", s.handleUpdateDraft())
			r.Delete("/compose/drafts/{id}", s.handleDeleteDraft())
		}
		r.Post("/compose/send", s.handleComposeSend())

		// Recommendation endpoints
		if s.recommendations != nil {
			r.Get("/recommendations", s.handleListRecommendations())
			r.Post("/recommendations", s.handleCreateRecommendation())
			r.Get("/recommendations/{id}", s.handleGetRecommendation())
			r.Patch("/recommendations/{id}", s.handleUpdateRecommendation())
		}

		// Digest endpoints
		if s.digests != nil {
			r.Get("/digests", s.handleListDigests())
			r.Get("/digests/latest", s.handleGetLatestDigest())
			r.Get("/digests/{id}", s.handleGetDigest())
			r.Patch("/digests/{id}", s.handleUpdateDigest())
		}

		// VIP endpoints
		if s.vip != nil {
			r.Get("/vip", s.handleListVIP())
			r.Post("/vip", s.handleAddVIP())
			r.Delete("/vip/{id}", s.handleRemoveVIP())
		}

		// Catch-all for unregistered API routes (returns 404 after auth check).
		// This ensures auth middleware runs even for non-existent endpoints.
		r.HandleFunc("/*", func(w http.ResponseWriter, r *http.Request) {
			WriteError(w, http.StatusNotFound, "not_found", "endpoint not found")
		})
	})

	return r
}
