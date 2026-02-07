package api

import (
	"net/http"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
)

// handleDownloadAttachment handles GET /api/v1/emails/{id}/attachments/{attachment_id}.
// This is a stub that will be fully implemented when IMAP attachment fetching is wired in.
func (s *Server) handleDownloadAttachment() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		_ = chi.URLParam(r, "id")
		_ = chi.URLParam(r, "attachment_id")

		// Attachment download requires fetching from IMAP, which is not yet wired.
		WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "attachment not found")
	}
}
