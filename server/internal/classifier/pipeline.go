// Package classifier implements the multi-layer email classification pipeline.
// Layer 0: Deterministic rules (VIP, newsletter domains, transactional patterns).
// Layer 1: Feature-based scoring with per-class weights and action bias.
// Layer 2: LLM escalation (handled by a separate provider interface).
package classifier

import (
	"context"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// ClassificationResult holds the output of the classification pipeline.
type ClassificationResult struct {
	Classification string
	Confidence     float64
	ClassifiedBy   string
	Reason         string
}

// EmailInput contains the email fields needed for classification.
type EmailInput struct {
	From            models.Contact
	To              []models.Contact
	CC              []models.Contact
	Subject         string
	TextBody        string
	HTMLBody        string
	Headers         map[string]string // key -> value (lowercased keys)
	ListUnsubscribe string            // List-Unsubscribe header value
}

// VIPChecker checks whether a sender is a VIP.
type VIPChecker interface {
	IsVIP(ctx context.Context, email string) (bool, error)
}

// SenderStatsProvider retrieves sender statistics for feature scoring.
type SenderStatsProvider interface {
	GetReplyRate(ctx context.Context, email string) (float64, bool, error)
	GetPriorClass(ctx context.Context, email string) (string, bool, error)
}

// LLMClassifier is the interface for Layer 2 LLM classification.
// It is optional; if nil, the pipeline falls back to feature results.
type LLMClassifier interface {
	Classify(ctx context.Context, input *EmailInput) (*ClassificationResult, error)
}

// Pipeline orchestrates the classification cascade: rules -> features -> LLM.
type Pipeline struct {
	rules    *RulesClassifier
	features *FeaturesClassifier
	llm      LLMClassifier
	logger   zerolog.Logger
}

// NewPipeline creates a classification pipeline.
func NewPipeline(vip VIPChecker, stats SenderStatsProvider, llm LLMClassifier, logger zerolog.Logger) *Pipeline {
	return &Pipeline{
		rules:    NewRulesClassifier(vip, logger),
		features: NewFeaturesClassifier(stats, logger),
		llm:      llm,
		logger:   logger.With().Str("component", "classifier.pipeline").Logger(),
	}
}

// Classify runs the classification pipeline on an email input.
// Returns a result that is never nil.
func (p *Pipeline) Classify(ctx context.Context, input *EmailInput) *ClassificationResult {
	// Layer 0: deterministic rules
	if result := p.rules.Classify(ctx, input); result != nil {
		p.logger.Debug().
			Str("classification", result.Classification).
			Float64("confidence", result.Confidence).
			Str("reason", result.Reason).
			Msg("classified by rules")
		return result
	}

	// Layer 1: feature-based scoring
	featResult := p.features.Classify(ctx, input)

	// Accept features result if confidence is high enough
	if shouldAcceptFeatures(featResult) {
		p.logger.Debug().
			Str("classification", featResult.Classification).
			Float64("confidence", featResult.Confidence).
			Msg("classified by features")
		return featResult
	}

	// Layer 2: LLM escalation
	if p.llm != nil {
		llmResult, err := p.llm.Classify(ctx, input)
		if err != nil {
			p.logger.Warn().Err(err).Msg("LLM classification failed, falling back to features")
		} else if llmResult != nil {
			return p.applyLLMResult(llmResult)
		}
	}

	// Fallback: use features result; if confidence < 0.5, default to action_required
	return p.fallback(featResult)
}

// shouldAcceptFeatures returns true if the feature result is confident enough.
func shouldAcceptFeatures(r *ClassificationResult) bool {
	if r.Confidence >= 0.85 {
		return true
	}
	// Lower threshold for action_required (err on the side of showing to user)
	if r.Classification == models.ClassActionRequired && r.Confidence >= 0.6 {
		return true
	}
	return false
}

// applyLLMResult applies LLM bias rules to the LLM result.
func (p *Pipeline) applyLLMResult(llmResult *ClassificationResult) *ClassificationResult {
	// LLM says action with confidence >= 0.5 -> accept
	if llmResult.Classification == models.ClassActionRequired && llmResult.Confidence >= 0.5 {
		return llmResult
	}
	// LLM says non-action but low confidence -> override to action (high bar to exclude)
	if llmResult.Classification != models.ClassActionRequired && llmResult.Confidence < 0.8 {
		return &ClassificationResult{
			Classification: models.ClassActionRequired,
			Confidence:     1.0 - llmResult.Confidence, // inverse as confidence
			ClassifiedBy:   models.ClassifiedByLLM,
			Reason:         "LLM uncertain about non-action classification; defaulting to action",
		}
	}
	return llmResult
}

// fallback returns the features result or defaults to action_required.
func (p *Pipeline) fallback(featResult *ClassificationResult) *ClassificationResult {
	if featResult.Confidence < 0.5 {
		return &ClassificationResult{
			Classification: models.ClassActionRequired,
			Confidence:     0.5,
			ClassifiedBy:   models.ClassifiedByFeatures,
			Reason:         "low confidence fallback to action_required",
		}
	}
	return featResult
}
