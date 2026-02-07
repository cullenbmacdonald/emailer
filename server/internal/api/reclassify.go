package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleReclassify handles POST /api/v1/emails/{id}/reclassify.
func (s *Server) handleReclassify() http.HandlerFunc {
	validClassifications := map[string]bool{
		models.ClassActionRequired: true,
		models.ClassNewsletter:     true,
		models.ClassFiltered:       true,
		models.ClassTransactional:  true,
	}

	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		ctx := r.Context()

		var req models.ReclassifyRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "invalid request body")
			return
		}

		if !validClassifications[req.NewClassification] {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "new_classification must be one of: action_required, newsletter, filtered, transactional")
			return
		}

		// Get the current classification for training signal
		current, err := s.classifications.GetClassification(ctx, id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get current classification")
			return
		}

		previousClass := current.Classification

		// Update the classification
		newClass := &models.Classification{
			Classification: req.NewClassification,
			Confidence:     1.0,
			ClassifiedBy:   models.ClassifiedByUser,
			Reason:         "user override",
			IsOverridden:   true,
		}
		if req.Confirm {
			newClass.Reason = "user confirmed"
		}

		if err := s.classifications.UpdateClassification(ctx, id, newClass); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "email not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to update classification")
			return
		}

		// Record training signal
		if err := s.classifications.RecordTrainingSignal(ctx, id, previousClass, req.NewClassification, req.Confirm); err != nil {
			// Log but don't fail the request
			_ = err
		}

		// Return the updated email
		email, err := s.emails.GetEmail(ctx, id)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get updated email")
			return
		}

		WriteJSON(w, http.StatusOK, email)
	}
}
