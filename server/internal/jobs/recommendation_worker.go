// Package jobs provides background workers for the email processing pipeline.
package jobs

import (
	"context"

	"github.com/cullenbmacdonald/emailer/internal/recommender"
	"github.com/rs/zerolog"
)

// RecommendationWorker processes newsletter emails from a channel and extracts
// recommendations using the Extractor.
type RecommendationWorker struct {
	extractor *recommender.Extractor
	input     <-chan recommender.EmailInput
	logger    zerolog.Logger
}

// NewRecommendationWorker creates a new recommendation worker.
func NewRecommendationWorker(
	extractor *recommender.Extractor,
	input <-chan recommender.EmailInput,
	logger zerolog.Logger,
) *RecommendationWorker {
	return &RecommendationWorker{
		extractor: extractor,
		input:     input,
		logger:    logger,
	}
}

// Run processes newsletter emails until the context is cancelled or the input
// channel is closed. It blocks until done.
func (w *RecommendationWorker) Run(ctx context.Context) {
	w.logger.Info().Msg("recommendation worker started")
	defer w.logger.Info().Msg("recommendation worker stopped")

	for {
		select {
		case <-ctx.Done():
			return
		case email, ok := <-w.input:
			if !ok {
				return
			}
			newCount, err := w.extractor.Extract(ctx, email)
			if err != nil {
				w.logger.Warn().Err(err).
					Str("email_id", email.EmailID).
					Msg("recommendation extraction failed")
				continue
			}
			if newCount > 0 {
				w.logger.Debug().
					Str("email_id", email.EmailID).
					Int("new_recommendations", newCount).
					Msg("recommendations extracted")
			}
		}
	}
}
