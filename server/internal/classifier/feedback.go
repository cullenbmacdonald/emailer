package classifier

import (
	"context"
	"time"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// TrainingStore records training signals and retrieves override history.
type TrainingStore interface {
	RecordTrainingSignal(ctx context.Context, emailID, previousClass, newClass string, isConfirm bool) error
	CountOverridesForSender(ctx context.Context, senderEmail, classification string) (int, error)
}

// SenderStatsUpdater updates sender statistics based on feedback.
type SenderStatsUpdater interface {
	IncrementClassCount(ctx context.Context, senderEmail, classification string) error
	SetMostCommonClass(ctx context.Context, senderEmail, classification string) error
}

// EmailLookup retrieves email metadata for feedback processing.
type EmailLookup interface {
	GetSenderEmail(ctx context.Context, emailID string) (string, error)
}

// FeedbackProcessor processes reclassify overrides to improve future classification.
type FeedbackProcessor struct {
	training    TrainingStore
	senderStats SenderStatsUpdater
	emailLookup EmailLookup
	logger      zerolog.Logger

	// trainingStartTime is when the system was first deployed.
	// During the training period (first 2 weeks), borderline thresholds are higher.
	trainingStartTime time.Time
}

// NewFeedbackProcessor creates a new feedback processor.
func NewFeedbackProcessor(
	training TrainingStore,
	senderStats SenderStatsUpdater,
	emailLookup EmailLookup,
	trainingStartTime time.Time,
	logger zerolog.Logger,
) *FeedbackProcessor {
	return &FeedbackProcessor{
		training:          training,
		senderStats:       senderStats,
		emailLookup:       emailLookup,
		trainingStartTime: trainingStartTime,
		logger:            logger.With().Str("component", "classifier.feedback").Logger(),
	}
}

// ProcessOverride handles a reclassify action. It records the training signal,
// updates sender stats, and detects false negatives.
func (fp *FeedbackProcessor) ProcessOverride(ctx context.Context, emailID, previousClass, newClass string, isConfirm bool) error {
	// Record the training signal
	if fp.training != nil {
		if err := fp.training.RecordTrainingSignal(ctx, emailID, previousClass, newClass, isConfirm); err != nil {
			fp.logger.Warn().Err(err).Str("email_id", emailID).Msg("failed to record training signal")
		}
	}

	// Look up sender email for stats updates
	senderEmail := ""
	if fp.emailLookup != nil {
		var err error
		senderEmail, err = fp.emailLookup.GetSenderEmail(ctx, emailID)
		if err != nil {
			fp.logger.Warn().Err(err).Str("email_id", emailID).Msg("failed to look up sender email")
			return nil
		}
	}

	if senderEmail == "" {
		return nil
	}

	// Update sender stats
	if fp.senderStats != nil {
		if err := fp.senderStats.IncrementClassCount(ctx, senderEmail, newClass); err != nil {
			fp.logger.Warn().Err(err).Str("sender", senderEmail).Msg("failed to increment class count")
		}
	}

	// Check if sender has 3+ overrides to the same class -> lock in as most_common_class
	if fp.training != nil && fp.senderStats != nil {
		count, err := fp.training.CountOverridesForSender(ctx, senderEmail, newClass)
		if err != nil {
			fp.logger.Warn().Err(err).Str("sender", senderEmail).Msg("failed to count overrides")
		} else if count >= 3 {
			if err := fp.senderStats.SetMostCommonClass(ctx, senderEmail, newClass); err != nil {
				fp.logger.Warn().Err(err).Str("sender", senderEmail).Msg("failed to set most common class")
			} else {
				fp.logger.Info().
					Str("sender", senderEmail).
					Str("class", newClass).
					Int("overrides", count).
					Msg("sender most_common_class updated based on override history")
			}
		}
	}

	// False negative detection: email rescued from filtered to action_required
	if previousClass == models.ClassFiltered && newClass == models.ClassActionRequired {
		fp.logger.Warn().
			Str("email_id", emailID).
			Str("sender", senderEmail).
			Msg("false negative detected: email rescued from filtered to action_required")
	}

	return nil
}

// IsTrainingPeriod returns true if we are within the first 2 weeks of deployment.
func (fp *FeedbackProcessor) IsTrainingPeriod() bool {
	return time.Since(fp.trainingStartTime) < 14*24*time.Hour
}

// BorderlineThreshold returns the confidence threshold for borderline items.
// During the training period, a higher threshold (0.85) is used to surface more
// items for user review. After training, the standard 0.80 threshold is used.
func (fp *FeedbackProcessor) BorderlineThreshold() float64 {
	if fp.IsTrainingPeriod() {
		return 0.85
	}
	return 0.80
}
