package api

import (
	"net/http"
	"strconv"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// handleSearchEmails handles GET /api/v1/search.
func (s *Server) handleSearchEmails() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if len(q) < 2 {
			WriteError(w, http.StatusBadRequest, models.ErrCodeInvalidParameter, "q parameter must be at least 2 characters")
			return
		}

		accountID := r.URL.Query().Get("account_id")
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

		resp, err := s.search.SearchEmails(r.Context(), q, accountID, cursor, limit)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to search emails")
			return
		}

		WriteJSON(w, http.StatusOK, resp)
	}
}
