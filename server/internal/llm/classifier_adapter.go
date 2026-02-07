package llm

import (
	"context"

	"github.com/cullenbmacdonald/emailer/internal/classifier"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

// ClassifierAdapter adapts an llm.Provider to the classifier.LLMClassifier interface.
type ClassifierAdapter struct {
	provider Provider
}

// NewClassifierAdapter wraps an LLM provider to implement classifier.LLMClassifier.
func NewClassifierAdapter(provider Provider) *ClassifierAdapter {
	return &ClassifierAdapter{provider: provider}
}

func (a *ClassifierAdapter) Classify(ctx context.Context, input *classifier.EmailInput) (*classifier.ClassificationResult, error) {
	toPosition := "to"
	if len(input.To) > 0 {
		// Check if the recipient is in To vs CC
		for _, cc := range input.CC {
			if cc.Email != "" {
				toPosition = "cc"
				break
			}
		}
	}

	req := ClassifyRequest{
		Subject:    input.Subject,
		From:       input.From.Email,
		FromName:   input.From.Name,
		ToPosition: toPosition,
		Body:       input.TextBody,
		Headers:    input.Headers,
	}

	resp, err := a.provider.Classify(ctx, req)
	if err != nil {
		return nil, err
	}

	return &classifier.ClassificationResult{
		Classification: resp.Classification,
		Confidence:     resp.Confidence,
		ClassifiedBy:   models.ClassifiedByLLM,
		Reason:         resp.Reasoning,
	}, nil
}
