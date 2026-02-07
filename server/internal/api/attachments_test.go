package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDownloadAttachment_NotFound(t *testing.T) {
	srv := newTestServer(&mockEmailStore{}, nil, nil, nil)
	req := authReq(http.MethodGet, "/api/v1/emails/e-123/attachments/a-456", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}
