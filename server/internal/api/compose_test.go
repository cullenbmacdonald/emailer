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

type mockComposeStore struct {
	listFn   func(ctx context.Context, cursor string, limit int) (*models.DraftListResponse, error)
	createFn func(ctx context.Context, d *models.Draft) (*models.Draft, error)
	updateFn func(ctx context.Context, id string, d *models.Draft) (*models.Draft, error)
	deleteFn func(ctx context.Context, id string) error
}

func (m *mockComposeStore) ListDrafts(ctx context.Context, cursor string, limit int) (*models.DraftListResponse, error) {
	if m.listFn != nil {
		return m.listFn(ctx, cursor, limit)
	}
	return &models.DraftListResponse{Data: []models.Draft{}}, nil
}

func (m *mockComposeStore) CreateDraft(ctx context.Context, d *models.Draft) (*models.Draft, error) {
	if m.createFn != nil {
		return m.createFn(ctx, d)
	}
	d.ID = "draft-1"
	d.CreatedAt = time.Now()
	d.UpdatedAt = time.Now()
	return d, nil
}

func (m *mockComposeStore) UpdateDraft(ctx context.Context, id string, d *models.Draft) (*models.Draft, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, d)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockComposeStore) DeleteDraft(ctx context.Context, id string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id)
	}
	return pgx.ErrNoRows
}

func TestComposeSend_Success(t *testing.T) {
	// No sender configured, should return stub response
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	body, _ := json.Marshal(models.ComposeRequest{
		AccountID: "acc-1",
		To:        []string{"user@example.com"},
		Subject:   "Hello",
		Body:      "World",
	})
	req := authReq(http.MethodPost, "/api/v1/compose/send", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestComposeSend_MissingAccountID(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	body, _ := json.Marshal(models.ComposeRequest{
		To:      []string{"user@example.com"},
		Subject: "Hello",
	})
	req := authReq(http.MethodPost, "/api/v1/compose/send", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestComposeSend_MissingRecipients(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	body, _ := json.Marshal(models.ComposeRequest{
		AccountID: "acc-1",
		Subject:   "Hello",
	})
	req := authReq(http.MethodPost, "/api/v1/compose/send", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListDrafts_Success(t *testing.T) {
	store := &mockComposeStore{
		listFn: func(_ context.Context, _ string, _ int) (*models.DraftListResponse, error) {
			return &models.DraftListResponse{
				Data: []models.Draft{{ID: "d1", AccountID: "acc-1", Subject: "Draft"}},
			}, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, store, nil)
	req := authReq(http.MethodGet, "/api/v1/compose/drafts", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestCreateDraft_Success(t *testing.T) {
	store := &mockComposeStore{}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, store, nil)
	body, _ := json.Marshal(models.ComposeRequest{
		AccountID: "acc-1",
		Subject:   "Draft subject",
	})
	req := authReq(http.MethodPost, "/api/v1/compose/drafts", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d", w.Code)
	}
}

func TestCreateDraft_MissingAccountID(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, &mockComposeStore{}, nil)
	body, _ := json.Marshal(models.ComposeRequest{Subject: "Draft"})
	req := authReq(http.MethodPost, "/api/v1/compose/drafts", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestUpdateDraft_Success(t *testing.T) {
	store := &mockComposeStore{
		updateFn: func(_ context.Context, id string, d *models.Draft) (*models.Draft, error) {
			d.ID = id
			d.UpdatedAt = time.Now()
			return d, nil
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, store, nil)
	body, _ := json.Marshal(models.ComposeRequest{AccountID: "acc-1", Subject: "Updated"})
	req := authReq(http.MethodPut, "/api/v1/compose/drafts/d-1", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestUpdateDraft_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, &mockComposeStore{}, nil)
	body, _ := json.Marshal(models.ComposeRequest{AccountID: "acc-1"})
	req := authReq(http.MethodPut, "/api/v1/compose/drafts/nonexistent", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestDeleteDraft_Success(t *testing.T) {
	store := &mockComposeStore{
		deleteFn: func(_ context.Context, _ string) error { return nil },
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, store, nil)
	req := authReq(http.MethodDelete, "/api/v1/compose/drafts/d-1", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", w.Code)
	}
}

func TestDeleteDraft_NotFound(t *testing.T) {
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, &mockComposeStore{}, nil)
	req := authReq(http.MethodDelete, "/api/v1/compose/drafts/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestListDrafts_StorageError(t *testing.T) {
	store := &mockComposeStore{
		listFn: func(_ context.Context, _ string, _ int) (*models.DraftListResponse, error) {
			return nil, errors.New("db error")
		},
	}
	srv := newTestServerFull(nil, nil, nil, nil, nil, nil, nil, nil, store, nil)
	req := authReq(http.MethodGet, "/api/v1/compose/drafts", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}
