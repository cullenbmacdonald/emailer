package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleSnooze handles POST /api/v1/emails/{id}/snooze.
func (s *Server) handleSnooze() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		ctx := r.Context()

		var req models.SnoozeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.ReturnAt.Before(time.Now()) {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "return_at must be in the future")
			return
		}

		// Check if the email exists
		email, err := s.emails.GetEmail(ctx, id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get email")
			return
		}

		// Determine snooze count
		snoozeCount := 1
		if email.Snooze != nil {
			snoozeCount = email.Snooze.SnoozeCount + 1
			// Deactivate existing active snooze
			if email.Snooze.IsActive {
				if err := s.snoozes.DeactivateSnooze(ctx, id); err != nil && !errors.Is(err, pgx.ErrNoRows) {
					WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to deactivate existing snooze")
					return
				}
			}
		}

		snooze, err := s.snoozes.CreateSnooze(ctx, id, req.ReturnAt, snoozeCount)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to create snooze")
			return
		}

		WriteJSON(w, http.StatusOK, snooze)
	}
}

// handleUnsnooze handles DELETE /api/v1/emails/{id}/snooze.
func (s *Server) handleUnsnooze() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		ctx := r.Context()

		err := s.snoozes.DeactivateSnooze(ctx, id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusConflict, models.ErrCodeConflict, "no active snooze on this email")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to cancel snooze")
			return
		}

		// Return the updated email
		email, err := s.emails.GetEmail(ctx, id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get email")
			return
		}

		WriteJSON(w, http.StatusOK, email)
	}
}
