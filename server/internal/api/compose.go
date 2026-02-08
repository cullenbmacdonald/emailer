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

// handleComposeSend handles POST /api/v1/compose/send.
func (s *Server) handleComposeSend() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req models.ComposeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.AccountID == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "account_id is required")
			return
		}
		if len(req.To) == 0 {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "at least one recipient is required")
			return
		}
		if req.Subject == "" && req.Body == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "subject or body is required")
			return
		}

		if s.sender == nil {
			// SMTP sending not yet wired; accept the request but return a stub response.
			WriteJSON(w, http.StatusOK, models.ComposeSendResponse{
				MessageID: "pending-smtp-not-configured",
			})
			return
		}

		resp, err := s.sender.Send(r.Context(), req.AccountID, req)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to send email")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}

// handleListDrafts handles GET /api/v1/compose/drafts.
func (s *Server) handleListDrafts() http.HandlerFunc {
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

		resp, err := s.compose.ListDrafts(r.Context(), cursor, limit)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list drafts")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}

// handleCreateDraft handles POST /api/v1/compose/drafts.
func (s *Server) handleCreateDraft() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req models.ComposeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if req.AccountID == "" {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "account_id is required")
			return
		}

		draft := &models.Draft{
			AccountID: req.AccountID,
			To:        req.To,
			CC:        req.CC,
			BCC:       req.BCC,
			Subject:   req.Subject,
			Body:      req.Body,
			HTMLBody:  req.HTMLBody,
			InReplyTo: req.InReplyTo,
		}

		created, err := s.compose.CreateDraft(r.Context(), draft)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to create draft")
			return
		}

		WriteJSON(w, http.StatusCreated, created)
	}
}

// handleUpdateDraft handles PUT /api/v1/compose/drafts/{id}.
func (s *Server) handleUpdateDraft() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		var req models.ComposeRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		draft := &models.Draft{
			AccountID: req.AccountID,
			To:        req.To,
			CC:        req.CC,
			BCC:       req.BCC,
			Subject:   req.Subject,
			Body:      req.Body,
			HTMLBody:  req.HTMLBody,
			InReplyTo: req.InReplyTo,
		}

		updated, err := s.compose.UpdateDraft(r.Context(), id, draft)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "draft not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to update draft")
			return
		}

		WriteJSON(w, http.StatusOK, updated)
	}
}

// handleDeleteDraft handles DELETE /api/v1/compose/drafts/{id}.
func (s *Server) handleDeleteDraft() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		err := s.compose.DeleteDraft(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "draft not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to delete draft")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}
