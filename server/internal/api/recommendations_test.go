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
	"github.com/cullenbmacdonald/emailer/internal/storage"
	"github.com/jackc/pgx/v5"
)

type mockRecommendationStore struct {
	listFn   func(ctx context.Context, opts storage.RecommendationListOptions) (*models.RecommendationListResponse, error)
	getFn    func(ctx context.Context, id string) (*models.RecommendationDetail, error)
	createFn func(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error)
	updateFn func(ctx context.Context, id, status string) error
}

func (m *mockRecommendationStore) ListRecommendations(ctx context.Context, opts storage.RecommendationListOptions) (*models.RecommendationListResponse, error) {
	if m.listFn != nil {
		return m.listFn(ctx, opts)
	}
	return &models.RecommendationListResponse{Data: []models.Recommendation{}}, nil
}

func (m *mockRecommendationStore) GetRecommendation(ctx context.Context, id string) (*models.RecommendationDetail, error) {
	if m.getFn != nil {
		return m.getFn(ctx, id)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockRecommendationStore) CreateRecommendation(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error) {
	if m.createFn != nil {
		return m.createFn(ctx, r)
	}
	r.ID = "new-id"
	r.CreatedAt = time.Now()
	return r, nil
}

func (m *mockRecommendationStore) UpdateRecommendationStatus(ctx context.Context, id, status string) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, status)
	}
	return pgx.ErrNoRows
}

func TestListRecommendations_Success(t *testing.T) {
	store := &mockRecommendationStore{
		listFn: func(_ context.Context, opts storage.RecommendationListOptions) (*models.RecommendationListResponse, error) {
			if opts.Type != "book" {
				t.Errorf("expected type book, got %s", opts.Type)
			}
			return &models.RecommendationListResponse{
				Data: []models.Recommendation{{ID: "r1", Type: "book", Title: "Test Book"}},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, store, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations?type=book", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestListRecommendations_InvalidType(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations?type=invalid", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListRecommendations_InvalidStatus(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations?status=bogus", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestGetRecommendation_Success(t *testing.T) {
	store := &mockRecommendationStore{
		getFn: func(_ context.Context, id string) (*models.RecommendationDetail, error) {
			return &models.RecommendationDetail{
				Recommendation:   models.Recommendation{ID: id, Title: "Test"},
				DuplicateSources: []models.DuplicateSource{},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, store, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations/r-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetRecommendation_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestCreateRecommendation_Success(t *testing.T) {
	store := &mockRecommendationStore{}
	srv := newTestServerFull(nil, nil, nil, nil, nil, store, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationCreateRequest{
		Type:  "book",
		Title: "Test Book",
	})
	req := authReq(http.MethodPost, "/api/v1/recommendations", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d", w.Code)
	}
}

func TestCreateRecommendation_MissingTitle(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationCreateRequest{Type: "book"})
	req := authReq(http.MethodPost, "/api/v1/recommendations", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestCreateRecommendation_MissingType(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationCreateRequest{Title: "Test"})
	req := authReq(http.MethodPost, "/api/v1/recommendations", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestUpdateRecommendation_Success(t *testing.T) {
	store := &mockRecommendationStore{
		updateFn: func(_ context.Context, _, _ string) error { return nil },
		getFn: func(_ context.Context, id string) (*models.RecommendationDetail, error) {
			return &models.RecommendationDetail{
				Recommendation:   models.Recommendation{ID: id, Status: "saved"},
				DuplicateSources: []models.DuplicateSource{},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, store, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationUpdateRequest{Status: "saved"})
	req := authReq(http.MethodPatch, "/api/v1/recommendations/r-1", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestUpdateRecommendation_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationUpdateRequest{Status: "saved"})
	req := authReq(http.MethodPatch, "/api/v1/recommendations/nonexistent", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestUpdateRecommendation_InvalidStatus(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, &mockRecommendationStore{}, nil, nil, nil, nil)
	body, _ := json.Marshal(models.RecommendationUpdateRequest{Status: "bogus"})
	req := authReq(http.MethodPatch, "/api/v1/recommendations/r-1", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListRecommendations_StorageError(t *testing.T) {
	store := &mockRecommendationStore{
		listFn: func(_ context.Context, _ storage.RecommendationListOptions) (*models.RecommendationListResponse, error) {
			return nil, errors.New("db error")
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, store, nil, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/recommendations", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}
