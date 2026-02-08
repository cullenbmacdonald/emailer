package api

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

type mockSearchStore struct {
	searchFn func(ctx context.Context, query, accountID, cursor string, limit int) (*models.SearchResponse, error)
}

func (m *mockSearchStore) SearchEmails(ctx context.Context, query, accountID, cursor string, limit int) (*models.SearchResponse, error) {
	if m.searchFn != nil {
		return m.searchFn(ctx, query, accountID, cursor, limit)
	}
	return &models.SearchResponse{Data: []models.SearchResult{}, Query: query}, nil
}

func TestSearchEmails_MissingQuery(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, &mockSearchStore{}, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestSearchEmails_ShortQuery(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, &mockSearchStore{}, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search?q=a", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestSearchEmails_Success(t *testing.T) {
	store := &mockSearchStore{
		searchFn: func(_ context.Context, query, accountID, _ string, _ int) (*models.SearchResponse, error) {
			if query != "test query" {
				t.Errorf("expected query 'test query', got %q", query)
			}
			return &models.SearchResponse{
				Data:  []models.SearchResult{{Email: models.Email{ID: "e1"}, HighlightSnippet: "<mark>test</mark>"}},
				Query: query,
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, store, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search?q=test+query", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestSearchEmails_InvalidLimit(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, &mockSearchStore{}, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search?q=test&limit=abc", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestSearchEmails_StorageError(t *testing.T) {
	store := &mockSearchStore{
		searchFn: func(_ context.Context, _, _, _ string, _ int) (*models.SearchResponse, error) {
			return nil, errors.New("db error")
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, store, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search?q=test", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}

func TestSearchEmails_WithAccountFilter(t *testing.T) {
	store := &mockSearchStore{
		searchFn: func(_ context.Context, _, accountID, _ string, _ int) (*models.SearchResponse, error) {
			if accountID != "acc-1" {
				t.Errorf("expected account_id acc-1, got %q", accountID)
			}
			return &models.SearchResponse{Data: []models.SearchResult{}, Query: "test"}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, store, nil, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/search?q=test&account_id=acc-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}
