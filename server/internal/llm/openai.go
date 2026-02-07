package llm

import (
	"context"
	"fmt"
)

// OpenAIProvider is a stub for future OpenAI API integration.
type OpenAIProvider struct {
	apiKey string
	model  string
}

// NewOpenAIProvider creates a new OpenAI provider.
// Returns an error since this provider is not yet implemented.
func NewOpenAIProvider(apiKey, model string) (*OpenAIProvider, error) {
	if apiKey == "" {
		return nil, fmt.Errorf("openai API key is required")
	}
	return &OpenAIProvider{apiKey: apiKey, model: model}, nil
}

func (o *OpenAIProvider) Name() string { return "openai" }

func (o *OpenAIProvider) Classify(_ context.Context, _ ClassifyRequest) (*ClassifyResponse, error) {
	return nil, fmt.Errorf("openai provider not implemented yet")
}

func (o *OpenAIProvider) ExtractRecommendations(_ context.Context, _ ExtractRequest) (*ExtractResponse, error) {
	return nil, fmt.Errorf("openai provider not implemented yet")
}
