package api

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
)

type mockDigestStore struct {
	listFn      func(ctx context.Context, cursor string, limit int) (*models.DigestListResponse, error)
	getLatestFn func(ctx context.Context, digestType string) (*models.DailyDigest, error)
	getFn       func(ctx context.Context, id string) (*models.DailyDigest, error)
	updateFn    func(ctx context.Context, id string, update models.DigestUpdateRequest) error
}

func (m *mockDigestStore) ListDigests(ctx context.Context, cursor string, limit int) (*models.DigestListResponse, error) {
	if m.listFn != nil {
		return m.listFn(ctx, cursor, limit)
	}
	return &models.DigestListResponse{Data: []models.DigestSummary{}}, nil
}

func (m *mockDigestStore) GetLatestDigest(ctx context.Context, digestType string) (*models.DailyDigest, error) {
	if m.getLatestFn != nil {
		return m.getLatestFn(ctx, digestType)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockDigestStore) GetDigest(ctx context.Context, id string) (*models.DailyDigest, error) {
	if m.getFn != nil {
		return m.getFn(ctx, id)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockDigestStore) UpdateDigest(ctx context.Context, id string, update models.DigestUpdateRequest) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, update)
	}
	return pgx.ErrNoRows
}

func TestListDigests_Success(t *testing.T) {
	store := &mockDigestStore{
		listFn: func(_ context.Context, _ string, _ int) (*models.DigestListResponse, error) {
			return &models.DigestListResponse{
				Data: []models.DigestSummary{{ID: "d1", DigestType: "morning"}},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestListDigests_StorageError(t *testing.T) {
	store := &mockDigestStore{
		listFn: func(_ context.Context, _ string, _ int) (*models.DigestListResponse, error) {
			return nil, errors.New("db error")
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}

func TestGetLatestDigest_Success(t *testing.T) {
	store := &mockDigestStore{
		getLatestFn: func(_ context.Context, dt string) (*models.DailyDigest, error) {
			return &models.DailyDigest{
				ID:          "d1",
				DigestType:  "morning",
				GeneratedAt: time.Now(),
				Sections:    []models.DigestSection{},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/latest", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetLatestDigest_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, &mockDigestStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/latest", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestGetLatestDigest_InvalidType(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, &mockDigestStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/latest?type=bogus", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestGetLatestDigest_WithTypeFilter(t *testing.T) {
	store := &mockDigestStore{
		getLatestFn: func(_ context.Context, dt string) (*models.DailyDigest, error) {
			if dt != "evening" {
				t.Errorf("expected type evening, got %s", dt)
			}
			return &models.DailyDigest{ID: "d1", DigestType: "evening", Sections: []models.DigestSection{}}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/latest?type=evening", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetDigest_Success(t *testing.T) {
	store := &mockDigestStore{
		getFn: func(_ context.Context, id string) (*models.DailyDigest, error) {
			return &models.DailyDigest{ID: id, DigestType: "morning", Sections: []models.DigestSection{}}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/d-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetDigest_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, &mockDigestStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/digests/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestUpdateDigest_Success(t *testing.T) {
	isRead := true
	store := &mockDigestStore{
		updateFn: func(_ context.Context, _ string, _ models.DigestUpdateRequest) error { return nil },
		getFn: func(_ context.Context, id string) (*models.DailyDigest, error) {
			return &models.DailyDigest{ID: id, DigestType: "morning", IsRead: true, Sections: []models.DigestSection{}}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, store, nil, nil, nil)
	body, _ := json.Marshal(models.DigestUpdateRequest{IsRead: &isRead})
	req := authReq(http.MethodPatch, "/api/v1/digests/d-1", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestUpdateDigest_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, &mockDigestStore{}, nil, nil, nil)
	body, _ := json.Marshal(models.DigestUpdateRequest{})
	req := authReq(http.MethodPatch, "/api/v1/digests/nonexistent", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}
