package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestAuthMiddlewareValidToken(t *testing.T) {
	srv := NewServer(":0", nil, "my-secret", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	req.Header.Set("Authorization", "Bearer my-secret")
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	// Should not get 401 (may get 404/405 since no routes are registered)
	if w.Code == http.StatusUnauthorized {
		t.Error("expected auth to pass with valid token")
	}
}

func TestAuthMiddlewareMissingHeader(t *testing.T) {
	srv := NewServer(":0", nil, "my-secret", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestAuthMiddlewareInvalidToken(t *testing.T) {
	srv := NewServer(":0", nil, "my-secret", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
	req.Header.Set("Authorization", "Bearer wrong-token")
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestAuthMiddlewareMalformedHeader(t *testing.T) {
	srv := NewServer(":0", nil, "my-secret", nil, BuildInfo{})

	tests := []struct {
		name  string
		value string
	}{
		{"no bearer prefix", "my-secret"},
		{"basic auth", "Basic dXNlcjpwYXNz"},
		{"empty bearer", "Bearer "},
		{"bearer only", "Bearer"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v1/test", nil)
			req.Header.Set("Authorization", tt.value)
			w := httptest.NewRecorder()
			srv.httpServer.Handler.ServeHTTP(w, req)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("expected 401, got %d", w.Code)
			}
		})
	}
}

func TestRequestIDMiddleware(t *testing.T) {
	srv := NewServer(":0", nil, "test-token", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	reqID := w.Header().Get("X-Request-ID")
	if reqID == "" {
		t.Error("expected X-Request-ID header to be set")
	}
	// UUID format: 8-4-4-4-12 = 36 chars
	if len(reqID) != 36 {
		t.Errorf("expected UUID format for request ID, got %q (len %d)", reqID, len(reqID))
	}
}

func TestRequestIDMiddlewarePreservesExisting(t *testing.T) {
	srv := NewServer(":0", nil, "test-token", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	req.Header.Set("X-Request-ID", "custom-id-123")
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	reqID := w.Header().Get("X-Request-ID")
	if reqID != "custom-id-123" {
		t.Errorf("expected preserved request ID custom-id-123, got %s", reqID)
	}
}
