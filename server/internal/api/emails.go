package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/cullenbmacdonald/emailer/internal/storage"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleListEmails handles GET /api/v1/emails.
func (s *Server) handleListEmails() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		view := r.URL.Query().Get("view")
		if view == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "view parameter is required")
			return
		}

		validViews := map[string]bool{
			storage.ViewActionQueue:  true,
			storage.ViewReadingQueue: true,
			storage.ViewFiltered:     true,
			storage.ViewAllInboxes:   true,
		}
		if !validViews[view] {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "view must be one of: action_queue, reading_queue, filtered, all_inboxes")
			return
		}

		opts := storage.EmailListOptions{
			View:      view,
			AccountID: r.URL.Query().Get("account_id"),
			Cursor:    r.URL.Query().Get("cursor"),
		}

		if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
			limit, err := strconv.Atoi(limitStr)
			if err != nil {
				WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "limit must be an integer")
				return
			}
			opts.Limit = limit
		}

		if isReadStr := r.URL.Query().Get("is_read"); isReadStr != "" {
			v, err := strconv.ParseBool(isReadStr)
			if err != nil {
				WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "is_read must be a boolean")
				return
			}
			opts.IsRead = &v
		}

		if isArchivedStr := r.URL.Query().Get("is_archived"); isArchivedStr != "" {
			v, err := strconv.ParseBool(isArchivedStr)
			if err != nil {
				WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "is_archived must be a boolean")
				return
			}
			opts.IsArchived = &v
		}

		resp, err := s.emails.ListEmails(r.Context(), opts)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list emails")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}

// handleGetEmail handles GET /api/v1/emails/{id}.
func (s *Server) handleGetEmail() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		detail, err := s.emails.GetEmailDetail(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get email")
			return
		}

		WriteJSON(w, http.StatusOK, detail)
	}
}

// handleUpdateEmail handles PATCH /api/v1/emails/{id}.
func (s *Server) handleUpdateEmail() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		var update models.EmailUpdateRequest
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		email, err := s.emails.UpdateEmail(r.Context(), id, update)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to update email")
			return
		}

		WriteJSON(w, http.StatusOK, email)
	}
}

// handleDeleteEmail handles DELETE /api/v1/emails/{id}.
func (s *Server) handleDeleteEmail() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		err := s.emails.DeleteEmail(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to delete email")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}
