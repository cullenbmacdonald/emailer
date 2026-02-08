package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleListVIP handles GET /api/v1/vip.
func (s *Server) handleListVIP() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		vips, err := s.vip.ListVIPSenders(r.Context())
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list VIP senders")
			return
		}

		WriteJSON(w, http.StatusOK, models.VIPListResponse{Data: vips})
	}
}

// handleAddVIP handles POST /api/v1/vip.
func (s *Server) handleAddVIP() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req models.VIPCreateRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.Email == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "email is required")
			return
		}

		vip, err := s.vip.AddVIPSender(r.Context(), req.Email, req.Name)
		if err != nil {
			// Check for unique constraint violation (duplicate)
			if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
				WriteError(w, http.StatusConflict, models.ErrCodeConflict, "VIP sender already exists")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to add VIP sender")
			return
		}

		WriteJSON(w, http.StatusCreated, vip)
	}
}

// handleRemoveVIP handles DELETE /api/v1/vip/{id}.
func (s *Server) handleRemoveVIP() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		err := s.vip.RemoveVIPSender(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "VIP sender not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to remove VIP sender")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}
