package llm

import (
	"context"
	"fmt"
)

// AnthropicProvider is a stub for future Anthropic API integration.
type AnthropicProvider struct {
	apiKey string
	model  string
}

// NewAnthropicProvider creates a new Anthropic provider.
// Returns an error since this provider is not yet implemented.
func NewAnthropicProvider(apiKey, model string) (*AnthropicProvider, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("anthropic API key is required")
	}
	return &AnthropicProvider{apiKey: apiKey, model: model}, nil
}

func (a *AnthropicProvider) Name() string { return "anthropic" }

func (a *AnthropicProvider) Classify(_ context.Context, _ ClassifyRequest) (*ClassifyResponse, error) {
	return nil, fmt.Errorf("anthropic provider not implemented yet")
}

func (a *AnthropicProvider) ExtractRecommendations(_ context.Context, _ ExtractRequest) (*ExtractResponse, error) {
	return nil, fmt.Errorf("anthropic provider not implemented yet")
}
