package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleListDigests handles GET /api/v1/digests.
func (s *Server) handleListDigests() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cursor := r.URL.Query().Get("cursor")
		limit := 0
		if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
			var err error
			limit, err = strconv.Atoi(limitStr)
			if err != nil {
				WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "limit must be an integer")
				return
			}
		}

		resp, err := s.digests.ListDigests(r.Context(), cursor, limit)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list digests")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}

// handleGetLatestDigest handles GET /api/v1/digests/latest.
func (s *Server) handleGetLatestDigest() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		digestType := r.URL.Query().Get("type")
		if digestType != "" && digestType != models.DigestTypeMorning && digestType != models.DigestTypeEvening {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "type must be morning or evening")
			return
		}

		digest, err := s.digests.GetLatestDigest(r.Context(), digestType)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "no digest has been generated yet")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get latest digest")
			return
		}

		WriteJSON(w, http.StatusOK, digest)
	}
}

// handleGetDigest handles GET /api/v1/digests/{id}.
func (s *Server) handleGetDigest() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		digest, err := s.digests.GetDigest(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "digest not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get digest")
			return
		}

		WriteJSON(w, http.StatusOK, digest)
	}
}

// handleUpdateDigest handles PATCH /api/v1/digests/{id}.
func (s *Server) handleUpdateDigest() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		var req models.DigestUpdateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		err := s.digests.UpdateDigest(r.Context(), id, req)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "digest not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to update digest")
			return
		}

		// Return the updated digest
		digest, err := s.digests.GetDigest(r.Context(), id)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get updated digest")
			return
		}

		WriteJSON(w, http.StatusOK, digest)
	}
}
