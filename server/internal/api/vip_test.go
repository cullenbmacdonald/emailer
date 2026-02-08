package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
)

type mockVIPStore struct {
	listFn   func(ctx context.Context) ([]models.VIPSender, error)
	addFn    func(ctx context.Context, email, name string) (*models.VIPSender, error)
	removeFn func(ctx context.Context, id string) error
}

func (m *mockVIPStore) ListVIPSenders(ctx context.Context) ([]models.VIPSender, error) {
	if m.listFn != nil {
		return m.listFn(ctx)
	}
	return []models.VIPSender{}, nil
}

func (m *mockVIPStore) AddVIPSender(ctx context.Context, email, name string) (*models.VIPSender, error) {
	if m.addFn != nil {
		return m.addFn(ctx, email, name)
	}
	return &models.VIPSender{ID: "v1", Email: email, Name: name, AddedAt: time.Now()}, nil
}

func (m *mockVIPStore) RemoveVIPSender(ctx context.Context, id string) error {
	if m.removeFn != nil {
		return m.removeFn(ctx, id)
	}
	return pgx.ErrNoRows
}

func TestListVIP_Success(t *testing.T) {
	store := &mockVIPStore{
		listFn: func(_ context.Context) ([]models.VIPSender, error) {
			return []models.VIPSender{{ID: "v1", Email: "boss@example.com"}}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, store, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/vip", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestAddVIP_Success(t *testing.T) {
	store := &mockVIPStore{}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, store, nil, nil)
	body, _ := json.Marshal(models.VIPCreateRequest{Email: "boss@example.com", Name: "Boss"})
	req := authReq(http.MethodPost, "/api/v1/vip", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d", w.Code)
	}
}

func TestAddVIP_MissingEmail(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, &mockVIPStore{}, nil, nil)
	body, _ := json.Marshal(models.VIPCreateRequest{Name: "Boss"})
	req := authReq(http.MethodPost, "/api/v1/vip", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestAddVIP_Duplicate(t *testing.T) {
	store := &mockVIPStore{
		addFn: func(_ context.Context, _, _ string) (*models.VIPSender, error) {
			return nil, fmt.Errorf("duplicate key value violates unique constraint")
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, store, nil, nil)
	body, _ := json.Marshal(models.VIPCreateRequest{Email: "boss@example.com"})
	req := authReq(http.MethodPost, "/api/v1/vip", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected 409, got %d", w.Code)
	}
}

func TestRemoveVIP_Success(t *testing.T) {
	store := &mockVIPStore{
		removeFn: func(_ context.Context, _ string) error { return nil },
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, store, nil, nil)
	req := authReq(http.MethodDelete, "/api/v1/vip/v-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", w.Code)
	}
}

func TestRemoveVIP_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, &mockVIPStore{}, nil, nil)
	req := authReq(http.MethodDelete, "/api/v1/vip/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}
