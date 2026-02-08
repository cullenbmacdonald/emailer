package recommender

import (
	"context"
	"fmt"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/llm"
	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog"
)

// RecommendationStore defines the storage operations needed by the extractor.
type RecommendationStore interface {
	CreateRecommendation(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error)
	FindSimilarRecommendation(ctx context.Context, title, recType string) (*models.Recommendation, error)
	IncrementDuplicateCount(ctx context.Context, id string) error
	AddDuplicateSource(ctx context.Context, recommendationID, emailID, newsletterName, contextSnippet string, date time.Time) error
}

// EmailUpdater defines the storage operation to update recommendation_count on emails.
type EmailUpdater interface {
	UpdateRecommendationCount(ctx context.Context, emailID string, count int) error
}

// Broadcaster defines the interface for sending WebSocket events.
type Broadcaster interface {
	BroadcastEvent(eventType string, payload any)
}

// Extractor extracts recommendations from newsletter emails using an LLM provider.
type Extractor struct {
	llmProvider llm.Provider
	store       RecommendationStore
	emailStore  EmailUpdater
	broadcaster Broadcaster
	logger      zerolog.Logger
}

// NewExtractor creates a new recommendation extractor.
func NewExtractor(
	provider llm.Provider,
	store RecommendationStore,
	emailStore EmailUpdater,
	broadcaster Broadcaster,
	logger zerolog.Logger,
) *Extractor {
	return &Extractor{
		llmProvider: provider,
		store:       store,
		emailStore:  emailStore,
		broadcaster: broadcaster,
		logger:      logger,
	}
}

// EmailInput holds the data needed to extract recommendations from a newsletter.
type EmailInput struct {
	EmailID     string
	AccountID   string
	Subject     string
	FromName    string
	FromAddress string
	TextBody    string
	ReceivedAt  time.Time
}

// Extract processes a newsletter email, extracts recommendations via the LLM,
// deduplicates them, stores new ones, and broadcasts events.
// Returns the number of new recommendations created.
func (e *Extractor) Extract(ctx context.Context, input EmailInput) (int, error) {
	logger := e.logger.With().
		Str("email_id", input.EmailID).
		Str("subject", input.Subject).
		Logger()

	resp, err := e.llmProvider.ExtractRecommendations(ctx, llm.ExtractRequest{
		Subject: input.Subject,
		From:    input.FromAddress,
		Body:    input.TextBody,
	})
	if err != nil {
		return 0, fmt.Errorf("extract recommendations: %w", err)
	}

	if len(resp.Recommendations) == 0 {
		logger.Debug().Msg("no recommendations extracted from newsletter")
		return 0, nil
	}

	newsletterName := input.FromName
	if newsletterName == "" {
		newsletterName = input.FromAddress
	}

	newCount := 0
	for _, extracted := range resp.Recommendations {
		if extracted.Title == "" {
			continue
		}

		recType, known := NormalizeLLMType(extracted.Type)
		if !known {
			logger.Warn().
				Str("llm_type", extracted.Type).
				Str("title", extracted.Title).
				Msg("unknown recommendation type from LLM, defaulting to other")
		}

		if !IsValidConfidence(extracted.Confidence) {
			extracted.Confidence = "medium"
		}

		// Only store high and medium confidence recommendations.
		if extracted.Confidence == "low" {
			logger.Debug().
				Str("title", extracted.Title).
				Msg("skipping low-confidence recommendation")
			continue
		}

		created, err := e.processOne(ctx, extracted, recType, input, newsletterName)
		if err != nil {
			logger.Warn().Err(err).
				Str("title", extracted.Title).
				Msg("failed to process recommendation, skipping")
			continue
		}
		if created {
			newCount++
		}
	}

	// Update the email's recommendation_count.
	totalCount := len(resp.Recommendations)
	if e.emailStore != nil {
		if err := e.emailStore.UpdateRecommendationCount(ctx, input.EmailID, totalCount); err != nil {
			logger.Warn().Err(err).Msg("failed to update email recommendation count")
		}
	}

	logger.Info().
		Int("extracted", len(resp.Recommendations)).
		Int("new", newCount).
		Msg("recommendation extraction complete")

	return newCount, nil
}

// processOne handles a single extracted recommendation: dedup check, create or update.
// Returns true if a new recommendation was created.
func (e *Extractor) processOne(
	ctx context.Context,
	extracted llm.ExtractedRecommendation,
	recType string,
	input EmailInput,
	newsletterName string,
) (bool, error) {
	// Check for duplicates using the storage layer's fuzzy match.
	existing, err := e.store.FindSimilarRecommendation(ctx, extracted.Title, recType)
	if err == nil && existing != nil {
		// Duplicate found: increment count and add source.
		if err := e.store.IncrementDuplicateCount(ctx, existing.ID); err != nil {
			return false, fmt.Errorf("increment duplicate count: %w", err)
		}
		if err := e.store.AddDuplicateSource(
			ctx, existing.ID, input.EmailID, newsletterName,
			extracted.Context, input.ReceivedAt,
		); err != nil {
			return false, fmt.Errorf("add duplicate source: %w", err)
		}
		return false, nil
	}
	// If err is non-nil it means no similar recommendation found (pgx.ErrNoRows wrapped),
	// so we create a new one.

	rec := &models.Recommendation{
		SourceEmailID:        input.EmailID,
		Type:                 recType,
		Title:                extracted.Title,
		Creator:              extracted.Creator,
		SourceNewsletterName: newsletterName,
		SourceDate:           input.ReceivedAt,
		ContextSnippet:       extracted.Context,
		Status:               models.RecStatusNew,
		IsUserAdded:          false,
	}

	created, err := e.store.CreateRecommendation(ctx, rec)
	if err != nil {
		return false, fmt.Errorf("create recommendation: %w", err)
	}

	if e.broadcaster != nil {
		e.broadcaster.BroadcastEvent(models.WSEventRecommendationNew, created)
	}

	return true, nil
}
