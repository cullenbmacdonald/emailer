package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestHealthEndpointWithoutDB(t *testing.T) {
	srv := NewServer(":0", nil, "test-token", nil, BuildInfo{
		Version: "1.0.0",
		Commit:  "abc123",
	})

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status 503, got %d", w.Code)
	}

	var resp models.HealthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if resp.Status != models.HealthStatusUnhealthy {
		t.Errorf("expected status unhealthy, got %s", resp.Status)
	}
	if resp.Version != "1.0.0" {
		t.Errorf("expected version 1.0.0, got %s", resp.Version)
	}
	if resp.Commit != "abc123" {
		t.Errorf("expected commit abc123, got %s", resp.Commit)
	}
	if resp.Checks == nil || resp.Checks.Database != models.CheckStatusError {
		t.Error("expected database check to be error")
	}
}

func TestHealthEndpointNoAuth(t *testing.T) {
	srv := NewServer(":0", nil, "secret-token", nil, BuildInfo{})

	// Health should work without Authorization header
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	// Should get a response (not 401)
	if w.Code == http.StatusUnauthorized {
		t.Error("health endpoint should not require authentication")
	}
}

func TestHealthResponseContentType(t *testing.T) {
	srv := NewServer(":0", nil, "test-token", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	ct := w.Header().Get("Content-Type")
	if ct != contentTypeJSON {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}
}

func TestHealthResponseUptimeIsPositive(t *testing.T) {
	srv := NewServer(":0", nil, "test-token", nil, BuildInfo{})

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	w := httptest.NewRecorder()
	srv.httpServer.Handler.ServeHTTP(w, req)

	var resp models.HealthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("decode error: %v", err)
	}

	if resp.UptimeSeconds < 0 {
		t.Errorf("expected non-negative uptime, got %d", resp.UptimeSeconds)
	}
}
