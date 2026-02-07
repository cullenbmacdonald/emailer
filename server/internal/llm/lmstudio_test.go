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

func TestLMStudioProvider_DefaultBaseURL(t *testing.T) {
	p := NewLMStudioProvider("", "test-model")
	if p.baseURL != "http://localhost:1234" {
		t.Errorf("got baseURL %q, want http://localhost:1234", p.baseURL)
	}
}

func TestLMStudioProvider_Name(t *testing.T) {
	p := NewLMStudioProvider("http://localhost:1234", "m")
	if p.Name() != "lmstudio" {
		t.Errorf("got name %q, want lmstudio", p.Name())
	}
}

func TestLMStudioProvider_Classify(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}

		var req openAIChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		if req.Model != "test-model" {
			t.Errorf("got model %q, want test-model", req.Model)
		}
		if req.ResponseFormat == nil || req.ResponseFormat.Type != "json_object" {
			t.Errorf("expected response_format json_object")
		}
		if len(req.Messages) != 2 {
			t.Errorf("got %d messages, want 2", len(req.Messages))
		}

		resp := openAIChatResponse{
			Choices: []openAIChoice{{
				Message: openAIMessage{
					Role:    "assistant",
					Content: `{"classification": "ACTION", "confidence": 0.9, "reasoning": "needs response"}`,
				},
			}},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewLMStudioProvider(server.URL, "test-model")
	resp, err := provider.Classify(context.Background(), ClassifyRequest{
		Subject:    "Review needed",
		From:       "bob@example.com",
		FromName:   "Bob",
		ToPosition: "to",
		Body:       "Please review.",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != models.ClassActionRequired {
		t.Errorf("got %q, want action_required", resp.Classification)
	}
	if resp.Confidence != 0.9 {
		t.Errorf("got confidence %f, want 0.9", resp.Confidence)
	}
}

func TestLMStudioProvider_ExtractRecommendations(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		resp := openAIChatResponse{
			Choices: []openAIChoice{{
				Message: openAIMessage{
					Role:    "assistant",
					Content: `{"recommendations": [{"type": "book", "title": "Neuromancer", "creator": "William Gibson", "context": "cyberpunk classic", "confidence": "high"}]}`,
				},
			}},
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewLMStudioProvider(server.URL, "test-model")
	resp, err := provider.ExtractRecommendations(context.Background(), ExtractRequest{
		Subject: "Newsletter",
		From:    "news@example.com",
		Body:    "Read Neuromancer by William Gibson.",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 1 {
		t.Fatalf("got %d recommendations, want 1", len(resp.Recommendations))
	}
	if resp.Recommendations[0].Title != "Neuromancer" {
		t.Errorf("got title %q, want Neuromancer", resp.Recommendations[0].Title)
	}
}

func TestLMStudioProvider_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte("internal error"))
	}))
	defer server.Close()

	provider := NewLMStudioProvider(server.URL, "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on server error")
	}
}

func TestLMStudioProvider_ConnectionRefused(t *testing.T) {
	provider := NewLMStudioProvider("http://localhost:1", "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on connection refused")
	}
	var connErr *ConnectionError
	if !errors.As(err, &connErr) {
		t.Logf("got error type %T: %v", err, err)
	}
}

func TestLMStudioProvider_EmptyChoices(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		resp := openAIChatResponse{Choices: []openAIChoice{}}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	provider := NewLMStudioProvider(server.URL, "test-model")
	_, err := provider.Classify(context.Background(), ClassifyRequest{Subject: "test"})
	if err == nil {
		t.Fatal("expected error on empty choices")
	}
}
