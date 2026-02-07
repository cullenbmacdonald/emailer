package api

import (
	"errors"
	"net/http"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
)

// handleListAccounts handles GET /api/v1/accounts.
func (s *Server) handleListAccounts() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		accounts, err := s.accounts.ListAccounts(r.Context())
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to list accounts")
			return
		}

		// Populate counts for each account
		for i := range accounts {
			counts, err := s.emails.CountEmailsByView(r.Context(), accounts[i].ID)
			if err != nil {
				WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get account counts")
				return
			}
			accounts[i].Counts = counts
		}

		WriteJSON(w, http.StatusOK, models.AccountListResponse{Data: accounts})
	}
}

// handleGetAccount handles GET /api/v1/accounts/{id}.
func (s *Server) handleGetAccount() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")

		account, err := s.accounts.GetAccount(r.Context(), id)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				WriteError(w, http.StatusNotFound, models.ErrCodeNotFound, "account not found")
				return
			}
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get account")
			return
		}

		counts, err := s.emails.CountEmailsByView(r.Context(), id)
		if err != nil {
			WriteError(w, http.StatusInternalServerError, models.ErrCodeInternalError, "failed to get account counts")
			return
		}
		account.Counts = counts

		WriteJSON(w, http.StatusOK, account)
	}
}
