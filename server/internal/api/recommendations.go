package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/cullenbmacdonald/emailer/internal/storage"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleListRecommendations handles GET /api/v1/recommendations.
func (s *Server) handleListRecommendations() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		opts := storage.RecommendationListOptions{
			Type:          r.URL.Query().Get("type"),
			Status:        r.URL.Query().Get("status"),
			AccountID:     r.URL.Query().Get("account_id"),
			SourceEmailID: r.URL.Query().Get("source_email_id"),
			Cursor:        r.URL.Query().Get("cursor"),
		}

		if opts.Type != "" && !isValidRecType(opts.Type) {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid recommendation type")
			return
		}
		if opts.Status != "" && !isValidRecStatus(opts.Status) {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid recommendation status")
			return
		}

		if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
			limit, err := strconv.Atoi(limitStr)
			if err != nil {
				WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "limit must be an integer")
				return
			}
			opts.Limit = limit
		}

		resp, err := s.recommendations.ListRecommendations(r.Context(), opts)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list recommendations")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}

// handleGetRecommendation handles GET /api/v1/recommendations/{id}.
func (s *Server) handleGetRecommendation() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		detail, err := s.recommendations.GetRecommendation(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "recommendation not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get recommendation")
			return
		}

		WriteJSON(w, http.StatusOK, detail)
	}
}

// handleCreateRecommendation handles POST /api/v1/recommendations.
func (s *Server) handleCreateRecommendation() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req models.RecommendationCreateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.Title == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "title is required")
			return
		}
		if req.Type == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "type is required")
			return
		}
		if !isValidRecType(req.Type) {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid recommendation type")
			return
		}

		rec := &models.Recommendation{
			Type:           req.Type,
			Title:          req.Title,
			Creator:        req.Creator,
			ContextSnippet: req.ContextSnippet,
			Status:         models.RecStatusNew,
			IsUserAdded:    true,
			SourceDate:     time.Now(),
		}

		created, err := s.recommendations.CreateRecommendation(r.Context(), rec)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to create recommendation")
			return
		}

		WriteJSON(w, http.StatusCreated, created)
	}
}

// handleUpdateRecommendation handles PATCH /api/v1/recommendations/{id}.
func (s *Server) handleUpdateRecommendation() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		var req models.RecommendationUpdateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.Status == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "status is required")
			return
		}
		if !isValidRecStatus(req.Status) {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid recommendation status")
			return
		}

		err := s.recommendations.UpdateRecommendationStatus(r.Context(), id, req.Status)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "recommendation not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to update recommendation")
			return
		}

		// Return the updated recommendation detail
		detail, err := s.recommendations.GetRecommendation(r.Context(), id)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get updated recommendation")
			return
		}

		WriteJSON(w, http.StatusOK, detail.Recommendation)
	}
}

func isValidRecType(t string) bool {
	for _, v := range models.ValidRecommendationTypes() {
		if v == t {
			return true
		}
	}
	return false
}

func isValidRecStatus(s string) bool {
	for _, v := range models.ValidRecommendationStatuses() {
		if v == s {
			return true
		}
	}
	return false
}
