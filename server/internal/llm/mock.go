package llm

import "context"

// MockProvider is a test-controllable LLM provider.
type MockProvider struct {
	ClassifyFunc               func(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error)
	ExtractRecommendationsFunc func(ctx context.Context, req ExtractRequest) (*ExtractResponse, error)
}

func (m *MockProvider) Name() string { return "mock" }

func (m *MockProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
	if m.ClassifyFunc != nil {
		return m.ClassifyFunc(ctx, req)
	}
	return &ClassifyResponse{
		Classification: "action_required",
		Confidence:     0.8,
		Reasoning:      "mock classification",
	}, nil
}

func (m *MockProvider) ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error) {
	if m.ExtractRecommendationsFunc != nil {
		return m.ExtractRecommendationsFunc(ctx, req)
	}
	return &ExtractResponse{Recommendations: nil}, nil
}
