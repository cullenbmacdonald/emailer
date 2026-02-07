package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestListAccounts_Success(t *testing.T) {
	accounts := &mockAccountStore{
		listFn: func(_ context.Context) ([]models.Account, error) {
			return []models.Account{
				{ID: "acc-1", Name: "Work", EmailAddress: "me@work.com"},
				{ID: "acc-2", Name: "Personal", EmailAddress: "me@home.com"},
			}, nil
		},
	}

	srv := newTestServer(&mockEmailStore{}, nil, nil, accounts)
	req := authReq(http.MethodGet, "/api/v1/accounts", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var resp models.AccountListResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Data) != 2 {
		t.Errorf("expected 2 accounts, got %d", len(resp.Data))
	}
}

func TestListAccounts_StorageError(t *testing.T) {
	accounts := &mockAccountStore{
		listFn: func(_ context.Context) ([]models.Account, error) {
			return nil, errors.New("db error")
		},
	}

	srv := newTestServer(&mockEmailStore{}, nil, nil, accounts)
	req := authReq(http.MethodGet, "/api/v1/accounts", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}

func TestGetAccount_Success(t *testing.T) {
	accounts := &mockAccountStore{
		getFn: func(_ context.Context, id string) (*models.Account, error) {
			return &models.Account{ID: id, Name: "Work"}, nil
		},
	}

	srv := newTestServer(&mockEmailStore{}, nil, nil, accounts)
	req := authReq(http.MethodGet, "/api/v1/accounts/acc-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetAccount_NotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, &mockAccountStore{})
	req := authReq(http.MethodGet, "/api/v1/accounts/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestAccountEndpoints_RequireAuth(t *testing.T) {
	srv := newTestServer(nil, nil, nil, &mockAccountStore{})

	endpoints := []string{"/api/v1/accounts", "/api/v1/accounts/acc-1"}
	for _, path := range endpoints {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		w := httptest.NewRecorder()
		srv.httpServer.Handler.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("GET %s: expected 401, got %d", path, w.Code)
		}
	}
}
