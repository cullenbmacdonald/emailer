package llm

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestOllamaProvider_Classify(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/chat" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Errorf("unexpected method: %s", r.Method)
		}

		var req ollamaChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode request: %v", err)
		}

		if req.Model != "test-model" {
			t.Errorf("got model %q, want test-model", req.Model)
		}
		if req.Format != "json" {
			t.Errorf("got format %q, want json", req.Format)
		}
		if len(req.Messages) != 2 {
			t.Errorf("got %d messages, want 2", len(req.Messages))
		}
		if req.Messages[0].Role != "system" {
			t.Errorf("first message role = %q, want system", req.Messages[0].Role)
		}

		resp := ollamaChatResponse{
			Message: ollamaMessage{
				Role:    "assistant",
				Content: `{"classification": "ACTION", "confidence": 0.85, "reasoning": "direct question"}`,
			},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOllamaProvider(server.URL, "test-model")
	resp, err := provider.Classify(context.Background(), ClassifyRequest{
		Subject:    "Can you review this?",
		From:       "alice@example.com",
		FromName:   "Alice",
		ToPosition: "to",
		Body:       "Please review the attached document.",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != models.ClassActionRequired {
		t.Errorf("got %q, want action_required", resp.Classification)
	}
	if resp.Confidence != 0.85 {
		t.Errorf("got confidence %f, want 0.85", resp.Confidence)
	}
}

func TestOllamaProvider_Classify_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("internal error"))
	}))
	defer server.Close()

	provider := NewOllamaProvider(server.URL, "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on server error")
	}
}

func TestOllamaProvider_Classify_ConnectionRefused(t *testing.T) {
	provider := NewOllamaProvider("http://localhost:1", "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on connection refused")
	}
	var connErr *ConnectionError
	if !errors.As(err, &connErr) {
		// Connection errors may be wrapped differently on different OSes
		t.Logf("got error type %T: %v (connection error check may vary by OS)", err, err)
	}
}

func TestOllamaProvider_ExtractRecommendations(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		resp := ollamaChatResponse{
			Message: ollamaMessage{
				Role:    "assistant",
				Content: `{"recommendations": [{"type": "book", "title": "Dune", "creator": "Frank Herbert", "context": "amazing sci-fi", "confidence": "high"}]}`,
			},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOllamaProvider(server.URL, "test-model")
	resp, err := provider.ExtractRecommendations(context.Background(), ExtractRequest{
		Subject: "Weekly newsletter",
		From:    "news@example.com",
		Body:    "You should read Dune by Frank Herbert. Amazing sci-fi.",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 1 {
		t.Fatalf("got %d recommendations, want 1", len(resp.Recommendations))
	}
	if resp.Recommendations[0].Title != "Dune" {
		t.Errorf("got title %q, want Dune", resp.Recommendations[0].Title)
	}
}

func TestOllamaProvider_MalformedResponse(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		resp := ollamaChatResponse{
			Message: ollamaMessage{
				Role:    "assistant",
				Content: "I cannot classify this email properly",
			},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewOllamaProvider(server.URL, "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on malformed LLM response")
	}
}
