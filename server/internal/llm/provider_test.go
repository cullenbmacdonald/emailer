package llm

import (
	"context"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

const (
	providerOllama    = "ollama"
	providerAnthropic = "anthropic"
	providerOpenAI    = "openai"
)

func TestNewProvider_Ollama(t *testing.T) {
	p, err := NewProvider(config.LLMConfig{
		Provider: providerOllama,
		Ollama:   config.OllamaConfig{BaseURL: "http://localhost:11434", Model: "test"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if p.Name() != providerOllama {
		t.Errorf("got name %q, want %s", p.Name(), providerOllama)
	}
}

func TestNewProvider_Anthropic(t *testing.T) {
	p, err := NewProvider(config.LLMConfig{
		Provider:  providerAnthropic,
		Anthropic: config.AnthropicConfig{APIKey: "sk-test", Model: "claude-sonnet-4-20250514"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if p.Name() != providerAnthropic {
		t.Errorf("got name %q, want %s", p.Name(), providerAnthropic)
	}
}

func TestNewProvider_AnthropicMissingKey(t *testing.T) {
	_, err := NewProvider(config.LLMConfig{
		Provider:  providerAnthropic,
		Anthropic: config.AnthropicConfig{Model: "claude-sonnet-4-20250514"},
	})
	if err == nil {
		t.Fatal("expected error for missing API key")
	}
}

func TestNewProvider_OpenAI(t *testing.T) {
	p, err := NewProvider(config.LLMConfig{
		Provider: providerOpenAI,
		OpenAI:   config.OpenAIConfig{APIKey: "sk-test", Model: "gpt-4o-mini"},
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if p.Name() != providerOpenAI {
		t.Errorf("got name %q, want %s", p.Name(), providerOpenAI)
	}
}

func TestNewProvider_Unknown(t *testing.T) {
	_, err := NewProvider(config.LLMConfig{Provider: "gemini"})
	if err == nil {
		t.Fatal("expected error for unknown provider")
	}
}

func TestNewProvider_Empty(t *testing.T) {
	_, err := NewProvider(config.LLMConfig{Provider: ""})
	if err == nil {
		t.Fatal("expected error for empty provider")
	}
}

func TestMockProvider_Defaults(t *testing.T) {
	m := &MockProvider{}
	resp, err := m.Classify(context.Background(), ClassifyRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != models.ClassActionRequired {
		t.Errorf("got %q, want %s", resp.Classification, models.ClassActionRequired)
	}
	if m.Name() != "mock" {
		t.Errorf("got name %q, want mock", m.Name())
	}
}

func TestMockProvider_CustomFunc(t *testing.T) {
	m := &MockProvider{
		ClassifyFunc: func(_ context.Context, _ ClassifyRequest) (*ClassifyResponse, error) {
			return &ClassifyResponse{Classification: models.ClassNewsletter, Confidence: 0.95}, nil
		},
	}
	resp, err := m.Classify(context.Background(), ClassifyRequest{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != models.ClassNewsletter {
		t.Errorf("got %q, want %s", resp.Classification, models.ClassNewsletter)
	}
}
