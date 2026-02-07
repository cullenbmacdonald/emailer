// Package llm provides LLM provider interfaces and implementations for
// email classification and recommendation extraction.
package llm

import (
	"context"
	"fmt"

	"github.com/cullenbmacdonald/emailer/internal/config"
)

// ClassifyRequest contains the email data to classify.
type ClassifyRequest struct {
	Subject    string
	From       string
	FromName   string
	ToPosition string // "to", "cc", or "bcc"
	Body       string
	Headers    map[string]string
}

// ClassifyResponse is the structured response from the LLM.
type ClassifyResponse struct {
	Classification string  `json:"classification"`
	Confidence     float64 `json:"confidence"`
	Reasoning      string  `json:"reasoning"`
}

// ExtractRequest contains the newsletter text to extract recommendations from.
type ExtractRequest struct {
	Subject string
	From    string
	Body    string
}

// ExtractResponse contains the extracted recommendations.
type ExtractResponse struct {
	Recommendations []ExtractedRecommendation `json:"recommendations"`
}

// ExtractedRecommendation is a single recommendation extracted by the LLM.
type ExtractedRecommendation struct {
	Type       string `json:"type"`
	Title      string `json:"title"`
	Creator    string `json:"creator"`
	Context    string `json:"context"`
	Confidence string `json:"confidence"` // "high", "medium", "low"
}

// Provider defines the interface for LLM providers.
type Provider interface {
	// Classify returns a classification result for the given email content.
	Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error)

	// ExtractRecommendations extracts structured recommendations from newsletter text.
	ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error)

	// Name returns the provider name.
	Name() string
}

// NewProvider creates an LLM provider based on configuration.
func NewProvider(cfg config.LLMConfig) (Provider, error) {
	switch cfg.Provider {
	case "ollama":
		return NewOllamaProvider(cfg.Ollama.BaseURL, cfg.Ollama.Model), nil
	case "lmstudio":
		return NewLMStudioProvider(cfg.LMStudio.BaseURL, cfg.LMStudio.Model), nil
	case "anthropic":
		return NewAnthropicProvider(cfg.Anthropic.APIKey, cfg.Anthropic.Model)
	case "openai":
		return NewOpenAIProvider(cfg.OpenAI.APIKey, cfg.OpenAI.Model)
	case "":
		return nil, fmt.Errorf("no LLM provider configured")
	default:
		return nil, fmt.Errorf("unknown LLM provider: %s", cfg.Provider)
	}
}
