package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5"
)

func TestSnooze_Success(t *testing.T) {
	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{ID: id, Subject: "Test"}, nil
		},
	}

	snoozes := &mockSnoozeStore{
		createFn: func(_ context.Context, emailID string, returnAt time.Time, count int) (*models.SnoozeState, error) {
			if count != 1 {
				t.Errorf("expected snooze count 1, got %d", count)
			}
			return &models.SnoozeState{
				ID:          "snz-1",
				EmailID:     emailID,
				ReturnAt:    returnAt,
				SnoozeCount: count,
				IsActive:    true,
			}, nil
		},
	}

	srv := newTestServer(emails, nil, snoozes, nil)
	body, _ := json.Marshal(models.SnoozeRequest{ReturnAt: time.Now().Add(time.Hour)})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/snooze", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d; body: %s", w.Code, w.Body.String())
	}

	var snz models.SnoozeState
	if err := json.NewDecoder(w.Body).Decode(&snz); err != nil {
		t.Fatal(err)
	}
	if snz.ID != "snz-1" {
		t.Errorf("expected snz-1, got %s", snz.ID)
	}
}

func TestSnooze_ReturnAtInPast(t *testing.T) {
	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{ID: id}, nil
		},
	}

	srv := newTestServer(emails, nil, &mockSnoozeStore{}, nil)
	body, _ := json.Marshal(models.SnoozeRequest{ReturnAt: time.Now().Add(-time.Hour)})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/snooze", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestSnooze_EmailNotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, &mockSnoozeStore{}, nil)
	body, _ := json.Marshal(models.SnoozeRequest{ReturnAt: time.Now().Add(time.Hour)})
	req := authReq(http.MethodPost, "/api/v1/emails/nonexistent/snooze", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestSnooze_MultiSnooze(t *testing.T) {
	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{
				ID: id,
				Snooze: &models.SnoozeState{
					ID:          "snz-old",
					SnoozeCount: 2,
					IsActive:    true,
				},
			}, nil
		},
	}

	var deactivated bool
	snoozes := &mockSnoozeStore{
		deactivateFn: func(_ context.Context, _ string) error {
			deactivated = true
			return nil
		},
		createFn: func(_ context.Context, _ string, _ time.Time, count int) (*models.SnoozeState, error) {
			if count != 3 {
				t.Errorf("expected snooze count 3, got %d", count)
			}
			return &models.SnoozeState{SnoozeCount: count, IsActive: true}, nil
		},
	}

	srv := newTestServer(emails, nil, snoozes, nil)
	body, _ := json.Marshal(models.SnoozeRequest{ReturnAt: time.Now().Add(time.Hour)})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/snooze", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d; body: %s", w.Code, w.Body.String())
	}
	if !deactivated {
		t.Error("expected old snooze to be deactivated")
	}
}

func TestSnooze_InvalidBody(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, &mockSnoozeStore{}, nil)
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/snooze", []byte("{bad"))
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestUnsnooze_Success(t *testing.T) {
	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{ID: id}, nil
		},
	}

	snoozes := &mockSnoozeStore{
		deactivateFn: func(_ context.Context, _ string) error {
			return nil
		},
	}

	srv := newTestServer(emails, nil, snoozes, nil)
	req := authReq(http.MethodDelete, "/api/v1/emails/e-123/snooze", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestUnsnooze_NoActiveSnooze(t *testing.T) {
	snoozes := &mockSnoozeStore{
		deactivateFn: func(_ context.Context, _ string) error {
			return pgx.ErrNoRows
		},
	}

	srv := newTestServer(&mockEmailStore{}, nil, snoozes, nil)
	req := authReq(http.MethodDelete, "/api/v1/emails/e-123/snooze", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected 409, got %d", w.Code)
	}
}
