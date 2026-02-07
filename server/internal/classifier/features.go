package classifier

import (
	"context"
	"regexp"
	"strings"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// Action phrase patterns.
var actionPhrases = []*regexp.Regexp{
	regexp.MustCompile(`(?i)\bcan you\b`),
	regexp.MustCompile(`(?i)\bcould you\b`),
	regexp.MustCompile(`(?i)\bwould you\b`),
	regexp.MustCompile(`(?i)\blet me know\b`),
	regexp.MustCompile(`(?i)\bwhat do you think\b`),
	regexp.MustCompile(`(?i)\bare you available\b`),
	regexp.MustCompile(`(?i)\bplease\s+(send|review|confirm|update|check|provide|share|approve)\b`),
	regexp.MustCompile(`(?i)\baction\s+required\b`),
	regexp.MustCompile(`(?i)\burgent\b`),
	regexp.MustCompile(`(?i)\basap\b`),
}

// Deadline mention patterns.
var deadlinePatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)\bby\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|end\s+of\s+(day|week)|eod|eow)\b`),
	regexp.MustCompile(`(?i)\bdeadline\b`),
	regexp.MustCompile(`(?i)\bdue\s+(date|by)\b`),
	regexp.MustCompile(`(?i)\bexpires?\s+(on|at|in)\b`),
}

// Unsubscribe text patterns in the body.
var unsubscribeBodyPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)\bunsubscribe\b`),
	regexp.MustCompile(`(?i)\bopt[\s-]?out\b`),
	regexp.MustCompile(`(?i)\bmanage\s+(your\s+)?preferences\b`),
	regexp.MustCompile(`(?i)\bemail\s+preferences\b`),
}

// linkPattern matches href links in HTML or URLs in text.
var linkPattern = regexp.MustCompile(`(?i)(https?://|href=)`)

// Features extracted from an email for scoring.
type Features struct {
	HasListUnsubscribe bool
	IsInToField        bool    // sender addressed recipient directly in To (not just CC/BCC)
	RecipientCount     int     // total To + CC count
	HasBulkHeaders     bool    // Precedence: bulk/list, X-Mailer patterns
	QuestionMarkCount  int     // number of ? in subject + body
	HasActionPhrases   bool    // matches action phrase patterns
	HasDeadlineMention bool    // mentions deadlines/due dates
	BodyLength         int     // text body length
	LinkCount          int     // number of links
	HasUnsubscribeText bool    // body contains unsubscribe language
	SenderReplyRate    float64 // how often user replies to this sender (0-1)
	SenderPriorClass   string  // most common classification for this sender
	IsNoReply          bool    // sender is a no-reply address
}

// ActionBias is the multiplier applied to action_required scores.
const ActionBias = 1.2

// FeaturesClassifier implements Layer 1 feature-based scoring.
type FeaturesClassifier struct {
	stats  SenderStatsProvider
	logger zerolog.Logger
}

// NewFeaturesClassifier creates a new features classifier.
func NewFeaturesClassifier(stats SenderStatsProvider, logger zerolog.Logger) *FeaturesClassifier {
	return &FeaturesClassifier{
		stats:  stats,
		logger: logger.With().Str("component", "classifier.features").Logger(),
	}
}

// ExtractFeatures extracts classification features from an email.
func ExtractFeatures(ctx context.Context, input *EmailInput, stats SenderStatsProvider) *Features {
	f := &Features{}

	// Header features
	f.HasListUnsubscribe = input.ListUnsubscribe != ""
	f.IsInToField = len(input.To) > 0 // has direct To recipients
	f.RecipientCount = len(input.To) + len(input.CC)

	// Bulk headers
	if prec, ok := input.Headers["precedence"]; ok {
		lower := strings.ToLower(prec)
		if lower == "bulk" || lower == "list" || lower == "junk" {
			f.HasBulkHeaders = true
		}
	}
	if _, ok := input.Headers["list-id"]; ok {
		f.HasBulkHeaders = true
	}

	// Question marks
	f.QuestionMarkCount = strings.Count(input.Subject, "?") + strings.Count(input.TextBody, "?")

	// Action phrases
	combined := input.Subject + " " + input.TextBody
	for _, pat := range actionPhrases {
		if pat.MatchString(combined) {
			f.HasActionPhrases = true
			break
		}
	}

	// Deadline mentions
	for _, pat := range deadlinePatterns {
		if pat.MatchString(combined) {
			f.HasDeadlineMention = true
			break
		}
	}

	// Body metrics
	f.BodyLength = len(input.TextBody)
	f.LinkCount = len(linkPattern.FindAllString(input.HTMLBody+input.TextBody, -1))

	// Unsubscribe text in body
	for _, pat := range unsubscribeBodyPatterns {
		if pat.MatchString(combined) {
			f.HasUnsubscribeText = true
			break
		}
	}

	// No-reply check
	f.IsNoReply = IsNoReplyAddress(input.From.Email)

	// Sender stats
	if stats != nil {
		if rate, ok, err := stats.GetReplyRate(ctx, input.From.Email); err == nil && ok {
			f.SenderReplyRate = rate
		}
		if class, ok, err := stats.GetPriorClass(ctx, input.From.Email); err == nil && ok {
			f.SenderPriorClass = class
		}
	}

	return f
}

// Classify scores an email across four classes and returns the best match.
func (fc *FeaturesClassifier) Classify(ctx context.Context, input *EmailInput) *ClassificationResult {
	f := ExtractFeatures(ctx, input, fc.stats)
	scores := scoreFeatures(f)

	// Find best class
	bestClass := models.ClassActionRequired
	bestScore := scores[models.ClassActionRequired]
	for class, score := range scores {
		if score > bestScore {
			bestClass = class
			bestScore = score
		}
	}

	// Normalize confidence
	total := 0.0
	for _, s := range scores {
		total += s
	}
	confidence := 0.0
	if total > 0 {
		confidence = bestScore / total
	}

	return &ClassificationResult{
		Classification: bestClass,
		Confidence:     confidence,
		ClassifiedBy:   models.ClassifiedByFeatures,
		Reason:         "feature-based scoring",
	}
}

// scoreFeatures computes raw scores for each classification class.
func scoreFeatures(f *Features) map[string]float64 {
	scores := map[string]float64{
		models.ClassActionRequired: 0,
		models.ClassNewsletter:     0,
		models.ClassFiltered:       0,
		models.ClassTransactional:  0,
	}

	// --- Action signals ---
	if f.IsInToField && f.RecipientCount <= 5 {
		scores[models.ClassActionRequired] += 2.0
	}
	if f.HasActionPhrases {
		scores[models.ClassActionRequired] += 3.0
	}
	if f.HasDeadlineMention {
		scores[models.ClassActionRequired] += 2.5
	}
	if f.QuestionMarkCount > 0 {
		scores[models.ClassActionRequired] += float64(min(f.QuestionMarkCount, 3)) * 0.5
	}
	if f.SenderReplyRate > 0.3 {
		scores[models.ClassActionRequired] += 2.0
	}
	if f.IsNoReply {
		scores[models.ClassActionRequired] -= 3.0 // strongly penalize action for no-reply
	}

	// --- Newsletter signals ---
	if f.HasListUnsubscribe {
		scores[models.ClassNewsletter] += 3.0
	}
	if f.HasUnsubscribeText {
		scores[models.ClassNewsletter] += 1.5
	}
	if f.HasBulkHeaders {
		scores[models.ClassNewsletter] += 2.0
	}
	if f.BodyLength > 2000 {
		scores[models.ClassNewsletter] += 1.0
	}
	if f.LinkCount > 10 {
		scores[models.ClassNewsletter] += 1.0
	}

	// --- Filtered signals ---
	if f.IsNoReply && !f.HasListUnsubscribe {
		scores[models.ClassFiltered] += 2.0
	}
	if f.RecipientCount > 10 {
		scores[models.ClassFiltered] += 1.5
	}
	if f.HasBulkHeaders && !f.HasListUnsubscribe {
		scores[models.ClassFiltered] += 2.0
	}

	// --- Transactional signals ---
	if f.IsNoReply {
		scores[models.ClassTransactional] += 1.0
	}
	// Short body from no-reply is likely transactional
	if f.IsNoReply && f.BodyLength < 500 {
		scores[models.ClassTransactional] += 1.5
	}

	// --- Sender prior class boost ---
	if f.SenderPriorClass != "" {
		scores[f.SenderPriorClass] += 3.0
	}

	// --- Action bias ---
	scores[models.ClassActionRequired] *= ActionBias

	// Ensure no negative scores
	for k, v := range scores {
		if v < 0 {
			scores[k] = 0
		}
	}

	return scores
}
