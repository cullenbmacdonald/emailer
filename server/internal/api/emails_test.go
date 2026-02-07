package api

import (
	"bytes"
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

// --- Mock stores ---

type mockEmailStore struct {
	listFn   func(ctx context.Context, opts storage.EmailListOptions) (*models.EmailListResponse, error)
	getFn    func(ctx context.Context, id string) (*models.Email, error)
	detailFn func(ctx context.Context, id string) (*models.EmailDetail, error)
	updateFn func(ctx context.Context, id string, update models.EmailUpdateRequest) (*models.Email, error)
	deleteFn func(ctx context.Context, id string) error
	countsFn func(ctx context.Context, accountID string) (*models.AccountCounts, error)
}

func (m *mockEmailStore) ListEmails(ctx context.Context, opts storage.EmailListOptions) (*models.EmailListResponse, error) {
	if m.listFn != nil {
		return m.listFn(ctx, opts)
	}
	return &models.EmailListResponse{Data: []models.Email{}}, nil
}

func (m *mockEmailStore) GetEmail(ctx context.Context, id string) (*models.Email, error) {
	if m.getFn != nil {
		return m.getFn(ctx, id)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockEmailStore) GetEmailDetail(ctx context.Context, id string) (*models.EmailDetail, error) {
	if m.detailFn != nil {
		return m.detailFn(ctx, id)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockEmailStore) UpdateEmail(ctx context.Context, id string, update models.EmailUpdateRequest) (*models.Email, error) {
	if m.updateFn != nil {
		return m.updateFn(ctx, id, update)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockEmailStore) DeleteEmail(ctx context.Context, id string) error {
	if m.deleteFn != nil {
		return m.deleteFn(ctx, id)
	}
	return pgx.ErrNoRows
}

func (m *mockEmailStore) CountEmailsByView(ctx context.Context, accountID string) (*models.AccountCounts, error) {
	if m.countsFn != nil {
		return m.countsFn(ctx, accountID)
	}
	return &models.AccountCounts{}, nil
}

type mockClassificationStore struct {
	getClassFn    func(ctx context.Context, emailID string) (*models.Classification, error)
	updateFn      func(ctx context.Context, emailID string, c *models.Classification) error
	trainSignalFn func(ctx context.Context, emailID, prev, next string, confirm bool) error
}

func (m *mockClassificationStore) GetClassification(ctx context.Context, emailID string) (*models.Classification, error) {
	if m.getClassFn != nil {
		return m.getClassFn(ctx, emailID)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockClassificationStore) UpdateClassification(ctx context.Context, emailID string, c *models.Classification) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, emailID, c)
	}
	return nil
}

func (m *mockClassificationStore) RecordTrainingSignal(ctx context.Context, emailID, prev, next string, confirm bool) error {
	if m.trainSignalFn != nil {
		return m.trainSignalFn(ctx, emailID, prev, next, confirm)
	}
	return nil
}

type mockSnoozeStore struct {
	createFn     func(ctx context.Context, emailID string, returnAt time.Time, count int) (*models.SnoozeState, error)
	getActiveFn  func(ctx context.Context, emailID string) (*models.SnoozeState, error)
	deactivateFn func(ctx context.Context, emailID string) error
}

func (m *mockSnoozeStore) CreateSnooze(ctx context.Context, emailID string, returnAt time.Time, count int) (*models.SnoozeState, error) {
	if m.createFn != nil {
		return m.createFn(ctx, emailID, returnAt, count)
	}
	return &models.SnoozeState{}, nil
}

func (m *mockSnoozeStore) GetActiveSnooze(ctx context.Context, emailID string) (*models.SnoozeState, error) {
	if m.getActiveFn != nil {
		return m.getActiveFn(ctx, emailID)
	}
	return nil, pgx.ErrNoRows
}

func (m *mockSnoozeStore) DeactivateSnooze(ctx context.Context, emailID string) error {
	if m.deactivateFn != nil {
		return m.deactivateFn(ctx, emailID)
	}
	return pgx.ErrNoRows
}

type mockAccountStore struct {
	listFn func(ctx context.Context) ([]models.Account, error)
	getFn  func(ctx context.Context, id string) (*models.Account, error)
}

func (m *mockAccountStore) ListAccounts(ctx context.Context) ([]models.Account, error) {
	if m.listFn != nil {
		return m.listFn(ctx)
	}
	return []models.Account{}, nil
}

func (m *mockAccountStore) GetAccount(ctx context.Context, id string) (*models.Account, error) {
	if m.getFn != nil {
		return m.getFn(ctx, id)
	}
	return nil, pgx.ErrNoRows
}

// --- Helpers ---

const testToken = "test-token"

func newTestServer(emails EmailStore, classifications ClassificationStore, snoozes SnoozeStore, accounts AccountStore) *Server {
	return NewServer(":0", nil, testToken, nil, BuildInfo{}, ServerDeps{
		Emails:          emails,
		Classifications: classifications,
		Snoozes:         snoozes,
		Accounts:        accounts,
	})
}

func authReq(method, url string, body []byte) *http.Request {
	var req *http.Request
	if body != nil {
		req = httptest.NewRequest(method, url, bytes.NewReader(body))
	} else {
		req = httptest.NewRequest(method, url, nil)
	}
	req.Header.Set("Authorization", "Bearer "+testToken)
	return req
}

// --- Tests ---

func TestListEmails_MissingView(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListEmails_InvalidView(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=bogus", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListEmails_Success(t *testing.T) {
	emails := &mockEmailStore{
		listFn: func(_ context.Context, opts storage.EmailListOptions) (*models.EmailListResponse, error) {
			if opts.View != "action_queue" {
				t.Errorf("expected view action_queue, got %s", opts.View)
			}
			return &models.EmailListResponse{
				Data:    []models.Email{{ID: "e1", Subject: "Test"}},
				HasMore: false,
			}, nil
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=action_queue", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var resp models.EmailListResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatal(err)
	}
	if len(resp.Data) != 1 {
		t.Errorf("expected 1 email, got %d", len(resp.Data))
	}
}

func TestListEmails_WithFilters(t *testing.T) {
	emails := &mockEmailStore{
		listFn: func(_ context.Context, opts storage.EmailListOptions) (*models.EmailListResponse, error) {
			if opts.AccountID != "acc-1" {
				t.Errorf("expected account_id acc-1, got %s", opts.AccountID)
			}
			if opts.IsRead == nil || !*opts.IsRead {
				t.Error("expected is_read=true")
			}
			if opts.Limit != 10 {
				t.Errorf("expected limit 10, got %d", opts.Limit)
			}
			return &models.EmailListResponse{Data: []models.Email{}}, nil
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=all_inboxes&account_id=acc-1&is_read=true&limit=10", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestListEmails_StorageError(t *testing.T) {
	emails := &mockEmailStore{
		listFn: func(_ context.Context, _ storage.EmailListOptions) (*models.EmailListResponse, error) {
			return nil, errors.New("db error")
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=filtered", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", w.Code)
	}
}

func TestGetEmail_Success(t *testing.T) {
	emails := &mockEmailStore{
		detailFn: func(_ context.Context, id string) (*models.EmailDetail, error) {
			return &models.EmailDetail{
				ID:       id,
				Email:    models.Email{ID: id, Subject: "Hello"},
				HTMLBody: "<p>body</p>",
			}, nil
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails/e-123", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestGetEmail_NotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestUpdateEmail_Success(t *testing.T) {
	isRead := true
	emails := &mockEmailStore{
		updateFn: func(_ context.Context, id string, update models.EmailUpdateRequest) (*models.Email, error) {
			if update.IsRead == nil || !*update.IsRead {
				t.Error("expected is_read=true in update")
			}
			return &models.Email{ID: id, IsRead: true}, nil
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	body, _ := json.Marshal(models.EmailUpdateRequest{IsRead: &isRead})
	req := authReq(http.MethodPatch, "/api/v1/emails/e-123", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestUpdateEmail_NotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	body, _ := json.Marshal(models.EmailUpdateRequest{})
	req := authReq(http.MethodPatch, "/api/v1/emails/nonexistent", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestDeleteEmail_Success(t *testing.T) {
	emails := &mockEmailStore{
		deleteFn: func(_ context.Context, _ string) error {
			return nil
		},
	}

	srv := newTestServer(emails, nil, nil, nil)
	req := authReq(http.MethodDelete, "/api/v1/emails/e-123", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", w.Code)
	}
}

func TestDeleteEmail_NotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodDelete, "/api/v1/emails/nonexistent", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestListEmails_InvalidLimit(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=action_queue&limit=abc", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestListEmails_InvalidIsRead(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails?view=action_queue&is_read=maybe", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestUpdateEmail_InvalidBody(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodPatch, "/api/v1/emails/e-123", []byte("{invalid"))
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestEmailEndpoints_RequireAuth(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)

	endpoints := []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/api/v1/emails?view=action_queue"},
		{http.MethodGet, "/api/v1/emails/e-1"},
		{http.MethodPatch, "/api/v1/emails/e-1"},
		{http.MethodDelete, "/api/v1/emails/e-1"},
	}

	for _, ep := range endpoints {
		req := httptest.NewRequest(ep.method, ep.path, nil)
		w := httptest.NewRecorder()
		srv.httpServer.Handler.ServeHTTP(w, req)

		if w.Code != http.StatusUnauthorized {
			t.Errorf("%s %s: expected 401, got %d", ep.method, ep.path, w.Code)
		}
	}
}
