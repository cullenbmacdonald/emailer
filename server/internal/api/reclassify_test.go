package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestReclassify_Success(t *testing.T) {
	var recordedPrev, recordedNew string
	var recordedConfirm bool

	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{
				ID:      id,
				Subject: "Test",
				Classification: &models.Classification{
					Classification: models.ClassNewsletter,
					ClassifiedBy:   models.ClassifiedByUser,
				},
			}, nil
		},
	}

	classifications := &mockClassificationStore{
		getClassFn: func(_ context.Context, _ string) (*models.Classification, error) {
			return &models.Classification{
				Classification: models.ClassFiltered,
				Confidence:     0.9,
				ClassifiedBy:   models.ClassifiedByFeatures,
			}, nil
		},
		updateFn: func(_ context.Context, _ string, c *models.Classification) error {
			if c.Classification != models.ClassActionRequired {
				t.Errorf("expected action_required, got %s", c.Classification)
			}
			if c.ClassifiedBy != models.ClassifiedByUser {
				t.Errorf("expected user, got %s", c.ClassifiedBy)
			}
			return nil
		},
		trainSignalFn: func(_ context.Context, _, prev, next string, confirm bool) error {
			recordedPrev = prev
			recordedNew = next
			recordedConfirm = confirm
			return nil
		},
	}

	srv := newTestServer(emails, classifications, nil, nil)
	body, _ := json.Marshal(models.ReclassifyRequest{NewClassification: models.ClassActionRequired})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/reclassify", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d; body: %s", w.Code, w.Body.String())
	}
	if recordedPrev != models.ClassFiltered {
		t.Errorf("expected prev=filtered, got %s", recordedPrev)
	}
	if recordedNew != models.ClassActionRequired {
		t.Errorf("expected new=action_required, got %s", recordedNew)
	}
	if recordedConfirm {
		t.Error("expected confirm=false")
	}
}

func TestReclassify_InvalidClassification(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, &mockClassificationStore{}, nil, nil)
	body, _ := json.Marshal(models.ReclassifyRequest{NewClassification: "invalid"})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/reclassify", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestReclassify_InvalidBody(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, &mockClassificationStore{}, nil, nil)
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/reclassify", []byte("{bad"))
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", w.Code)
	}
}

func TestReclassify_EmailNotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, &mockClassificationStore{}, nil, nil)
	body, _ := json.Marshal(models.ReclassifyRequest{NewClassification: models.ClassActionRequired})
	req := authReq(http.MethodPost, "/api/v1/emails/nonexistent/reclassify", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestReclassify_Confirm(t *testing.T) {
	var gotConfirm bool
	emails := &mockEmailStore{
		getFn: func(_ context.Context, id string) (*models.Email, error) {
			return &models.Email{ID: id}, nil
		},
	}
	classifications := &mockClassificationStore{
		getClassFn: func(_ context.Context, _ string) (*models.Classification, error) {
			return &models.Classification{Classification: models.ClassFiltered}, nil
		},
		trainSignalFn: func(_ context.Context, _, _, _ string, confirm bool) error {
			gotConfirm = confirm
			return nil
		},
	}

	srv := newTestServer(emails, classifications, nil, nil)
	body, _ := json.Marshal(models.ReclassifyRequest{NewClassification: models.ClassFiltered, Confirm: true})
	req := authReq(http.MethodPost, "/api/v1/emails/e-123/reclassify", body)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if !gotConfirm {
		t.Error("expected confirm=true")
	}
}
