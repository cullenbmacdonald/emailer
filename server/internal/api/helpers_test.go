package api

import (
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestWriteJSON(t *testing.T) {
	w := httptest.NewRecorder()
	data := map[string]string{"key": "value"}
	WriteJSON(w, 200, data)

	if w.Code != 200 {
		t.Errorf("expected status 200, got %d", w.Code)
	}
	if ct := w.Header().Get("Content-Type"); ct != contentTypeJSON {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}

	var result map[string]string
	if err := json.NewDecoder(w.Body).Decode(&result); err != nil {
		t.Fatalf("decode error: %v", err)
	}
	if result["key"] != "value" {
		t.Errorf("expected key=value, got %s", result["key"])
	}
}

func TestWriteError(t *testing.T) {
	w := httptest.NewRecorder()
	WriteError(w, 400, "invalid_parameter", "bad input")

	if w.Code != 400 {
		t.Errorf("expected status 400, got %d", w.Code)
	}

	var apiErr models.APIError
	if err := json.NewDecoder(w.Body).Decode(&apiErr); err != nil {
		t.Fatalf("decode error: %v", err)
	}
	if apiErr.Code != "invalid_parameter" {
		t.Errorf("expected code invalid_parameter, got %s", apiErr.Code)
	}
	if apiErr.Message != "bad input" {
		t.Errorf("expected message 'bad input', got %s", apiErr.Message)
	}
}

func TestWriteJSONSetsContentTypeBeforeBody(t *testing.T) {
	w := httptest.NewRecorder()
	WriteJSON(w, 201, map[string]int{"count": 42})

	if w.Code != 201 {
		t.Errorf("expected status 201, got %d", w.Code)
	}
	if ct := w.Header().Get("Content-Type"); ct != contentTypeJSON {
		t.Errorf("expected Content-Type application/json, got %s", ct)
	}
}
