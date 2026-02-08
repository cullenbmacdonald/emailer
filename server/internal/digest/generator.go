// Package digest implements daily digest generation for morning and evening summaries.
package digest

import (
	"context"
	"fmt"
	"math"
	"regexp"
	"strconv"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog/log"
)

// DataSource abstracts the database queries needed for digest generation.
// Each method corresponds to one or more digest sections.
type DataSource interface {
	// ActionQueueSummary returns the count of unarchived action_required emails
	// and per-account breakdowns.
	ActionQueueSummary(ctx context.Context) (int, []models.AccountCount, error)

	// ReturningToday returns snooze states where return_at falls on the given date.
	ReturningToday(ctx context.Context, date time.Time) ([]DigestSnoozeItem, error)

	// ReadingQueueCount returns the count of unarchived newsletter emails.
	ReadingQueueCount(ctx context.Context) (int, error)

	// BorderlineFiltered returns top N filtered emails with confidence < threshold.
	BorderlineFiltered(ctx context.Context, limit int, threshold float64) ([]DigestBorderlineItem, error)

	// NotableTransactional returns transactional emails with notable content
	// (shipping keywords, large dollar amounts) received since the given time.
	NotableTransactional(ctx context.Context, since time.Time) ([]DigestTransactionalItem, error)

	// TodayStats returns count of emails archived and sent today.
	TodayStats(ctx context.Context, since time.Time) (archived int, sent int, err error)

	// NewslettersToday returns newsletters received since the given time.
	NewslettersToday(ctx context.Context, since time.Time) ([]DigestNewsletterItem, error)

	// SnoozeNudges returns emails snoozed 3+ times with snooze count and age.
	SnoozeNudges(ctx context.Context, minSnoozeCount int) ([]DigestSnoozeNudge, error)
}

// DigestSnoozeItem represents a snooze returning today.
type DigestSnoozeItem struct {
	EmailID  string
	Subject  string
	From     string
	ReturnAt time.Time
}

// DigestBorderlineItem represents a filtered email near the confidence threshold.
type DigestBorderlineItem struct {
	EmailID    string
	Subject    string
	From       string
	Confidence float64
	Reason     string
}

// DigestTransactionalItem represents a notable transactional email.
type DigestTransactionalItem struct {
	EmailID       string
	Subject       string
	From          string
	HighlightType string // "shipping" or "large_charge"
	DisplayText   string
}

// DigestNewsletterItem represents a newsletter received today.
type DigestNewsletterItem struct {
	EmailID        string
	NewsletterName string
	Subject        string
}

// DigestSnoozeNudge represents an email snoozed many times.
type DigestSnoozeNudge struct {
	EmailID              string
	Subject              string
	From                 string
	SnoozeCount          int
	DaysSinceFirstSnooze int
}

// DigestSaver saves a generated digest.
type DigestSaver interface {
	SaveDigest(ctx context.Context, d *models.DailyDigest) (*models.DailyDigest, error)
	GetLatestDigest(ctx context.Context, digestType string) (*models.DailyDigest, error)
}

// Broadcaster broadcasts WebSocket events.
type Broadcaster interface {
	BroadcastEvent(eventType string, payload any)
}

// Generator assembles daily digest payloads by querying the data source.
type Generator struct {
	data        DataSource
	saver       DigestSaver
	broadcaster Broadcaster
}

// NewGenerator creates a new digest generator.
func NewGenerator(data DataSource, saver DigestSaver, broadcaster Broadcaster) *Generator {
	return &Generator{
		data:        data,
		saver:       saver,
		broadcaster: broadcaster,
	}
}

// Generate creates a digest of the given type for the given date/time.
func (g *Generator) Generate(ctx context.Context, digestType string, now time.Time) (*models.DailyDigest, error) {
	var sections []models.DigestSection

	switch digestType {
	case models.DigestTypeMorning:
		sections = g.buildMorningSections(ctx, now)
	case models.DigestTypeEvening:
		sections = g.buildEveningSections(ctx, now)
	default:
		return nil, fmt.Errorf("unknown digest type: %s", digestType)
	}

	digest := &models.DailyDigest{
		DigestType: digestType,
		Sections:   sections,
	}

	saved, err := g.saver.SaveDigest(ctx, digest)
	if err != nil {
		return nil, fmt.Errorf("save digest: %w", err)
	}

	if g.broadcaster != nil {
		g.broadcaster.BroadcastEvent(models.WSEventDigestAvailable, map[string]any{
			"digest_id":   saved.ID,
			"digest_type": saved.DigestType,
		})
	}

	return saved, nil
}

func (g *Generator) buildMorningSections(ctx context.Context, now time.Time) []models.DigestSection {
	var sections []models.DigestSection

	// 1. action_queue_summary
	if s := g.actionQueueSummary(ctx); s != nil {
		sections = append(sections, *s)
	}

	// 2. returning_today
	if s := g.returningToday(ctx, now); s != nil {
		sections = append(sections, *s)
	}

	// 3. reading_queue_summary
	if s := g.readingQueueSummary(ctx); s != nil {
		sections = append(sections, *s)
	}

	// 4. borderline_items
	if s := g.borderlineItems(ctx); s != nil {
		sections = append(sections, *s)
	}

	// 5. notable_transactional
	if s := g.notableTransactional(ctx, now); s != nil {
		sections = append(sections, *s)
	}

	return sections
}

func (g *Generator) buildEveningSections(ctx context.Context, now time.Time) []models.DigestSection {
	var sections []models.DigestSection

	// 1. today_stats
	if s := g.todayStats(ctx, now); s != nil {
		sections = append(sections, *s)
	}

	// 2. still_pending
	if s := g.stillPending(ctx); s != nil {
		sections = append(sections, *s)
	}

	// 3. newsletters_today
	if s := g.newslettersToday(ctx, now); s != nil {
		sections = append(sections, *s)
	}

	// 4. snooze_nudges
	if s := g.snoozeNudges(ctx); s != nil {
		sections = append(sections, *s)
	}

	// 5. notable_transactional
	if s := g.notableTransactional(ctx, now); s != nil {
		sections = append(sections, *s)
	}

	return sections
}

func (g *Generator) actionQueueSummary(ctx context.Context) *models.DigestSection {
	count, breakdown, err := g.data.ActionQueueSummary(ctx)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get action queue summary")
		return nil
	}
	if count == 0 {
		return nil
	}

	return &models.DigestSection{
		Type:             "action_queue_summary",
		Title:            "Action Queue",
		Subtitle:         fmt.Sprintf("%d emails need your attention", count),
		Count:            intPtr(count),
		AccountBreakdown: breakdown,
	}
}

func (g *Generator) returningToday(ctx context.Context, now time.Time) *models.DigestSection {
	items, err := g.data.ReturningToday(ctx, now)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get returning today")
		return nil
	}
	if len(items) == 0 {
		return nil
	}

	digestItems := make([]models.DigestItem, len(items))
	for i, item := range items {
		returnAt := item.ReturnAt
		digestItems[i] = models.DigestItem{
			Type:     "snooze_return",
			EmailID:  item.EmailID,
			Subject:  item.Subject,
			From:     item.From,
			ReturnAt: &returnAt,
		}
	}

	return &models.DigestSection{
		Type:     "returning_today",
		Title:    "Returning Today",
		Subtitle: fmt.Sprintf("%d snoozed emails returning", len(items)),
		Count:    intPtr(len(items)),
		Items:    digestItems,
	}
}

func (g *Generator) readingQueueSummary(ctx context.Context) *models.DigestSection {
	count, err := g.data.ReadingQueueCount(ctx)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get reading queue count")
		return nil
	}
	if count == 0 {
		return nil
	}

	return &models.DigestSection{
		Type:     "reading_queue_summary",
		Title:    "Reading Queue",
		Subtitle: fmt.Sprintf("%d newsletters waiting", count),
		Count:    intPtr(count),
	}
}

func (g *Generator) borderlineItems(ctx context.Context) *models.DigestSection {
	// During training period we'd show 5, but default to 3.
	limit := 3
	threshold := 0.80

	items, err := g.data.BorderlineFiltered(ctx, limit, threshold)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get borderline items")
		return nil
	}
	if len(items) == 0 {
		return nil
	}

	digestItems := make([]models.DigestItem, len(items))
	for i, item := range items {
		conf := item.Confidence
		digestItems[i] = models.DigestItem{
			Type:        "borderline",
			EmailID:     item.EmailID,
			Subject:     item.Subject,
			From:        item.From,
			Confidence:  &conf,
			Explanation: item.Reason,
		}
	}

	return &models.DigestSection{
		Type:     "borderline_items",
		Title:    "Borderline Items",
		Subtitle: "These filtered emails might need your attention",
		Count:    intPtr(len(items)),
		Items:    digestItems,
	}
}

var (
	shippingPattern    = regexp.MustCompile(`(?i)(shipped|out for delivery|tracking|in transit|delivered)`)
	largeChargePattern = regexp.MustCompile(`\$([0-9,]+(?:\.[0-9]{2})?)`)
)

func (g *Generator) notableTransactional(ctx context.Context, now time.Time) *models.DigestSection {
	// Look at transactional emails from the last 24 hours.
	since := now.Add(-24 * time.Hour)
	items, err := g.data.NotableTransactional(ctx, since)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get notable transactional")
		return nil
	}
	if len(items) == 0 {
		return nil
	}

	digestItems := make([]models.DigestItem, len(items))
	for i, item := range items {
		digestItems[i] = models.DigestItem{
			Type:          "transactional",
			EmailID:       item.EmailID,
			Subject:       item.Subject,
			From:          item.From,
			HighlightType: item.HighlightType,
			DisplayText:   item.DisplayText,
		}
	}

	return &models.DigestSection{
		Type:     "notable_transactional",
		Title:    "Notable Transactional",
		Subtitle: fmt.Sprintf("%d notable transactional emails", len(items)),
		Count:    intPtr(len(items)),
		Items:    digestItems,
	}
}

func (g *Generator) todayStats(ctx context.Context, now time.Time) *models.DigestSection {
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	archived, sent, err := g.data.TodayStats(ctx, startOfDay)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get today stats")
		return nil
	}
	if archived == 0 && sent == 0 {
		return nil
	}

	return &models.DigestSection{
		Type:          "today_stats",
		Title:         "Today's Activity",
		Subtitle:      fmt.Sprintf("Archived %d, sent %d emails today", archived, sent),
		ArchivedCount: intPtr(archived),
		SentCount:     intPtr(sent),
	}
}

func (g *Generator) stillPending(ctx context.Context) *models.DigestSection {
	count, _, err := g.data.ActionQueueSummary(ctx)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get still pending count")
		return nil
	}
	if count == 0 {
		return nil
	}

	return &models.DigestSection{
		Type:     "still_pending",
		Title:    "Still Pending",
		Subtitle: fmt.Sprintf("%d action items still pending", count),
		Count:    intPtr(count),
	}
}

func (g *Generator) newslettersToday(ctx context.Context, now time.Time) *models.DigestSection {
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	items, err := g.data.NewslettersToday(ctx, startOfDay)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get newsletters today")
		return nil
	}
	if len(items) == 0 {
		return nil
	}

	digestItems := make([]models.DigestItem, len(items))
	for i, item := range items {
		digestItems[i] = models.DigestItem{
			Type:           "newsletter",
			EmailID:        item.EmailID,
			NewsletterName: item.NewsletterName,
			Subject:        item.Subject,
		}
	}

	return &models.DigestSection{
		Type:     "newsletters_today",
		Title:    "Newsletters Today",
		Subtitle: fmt.Sprintf("%d newsletters arrived today", len(items)),
		Count:    intPtr(len(items)),
		Items:    digestItems,
	}
}

func (g *Generator) snoozeNudges(ctx context.Context) *models.DigestSection {
	items, err := g.data.SnoozeNudges(ctx, 3)
	if err != nil {
		log.Warn().Err(err).Msg("digest: failed to get snooze nudges")
		return nil
	}
	if len(items) == 0 {
		return nil
	}

	digestItems := make([]models.DigestItem, len(items))
	for i, item := range items {
		sc := item.SnoozeCount
		ds := item.DaysSinceFirstSnooze
		digestItems[i] = models.DigestItem{
			Type:                 "snooze_nudge",
			EmailID:              item.EmailID,
			Subject:              item.Subject,
			From:                 item.From,
			SnoozeCount:          &sc,
			DaysSinceFirstSnooze: &ds,
		}
	}

	return &models.DigestSection{
		Type:     "snooze_nudges",
		Title:    "Snooze Nudges",
		Subtitle: fmt.Sprintf("%d emails snoozed repeatedly", len(items)),
		Count:    intPtr(len(items)),
		Items:    digestItems,
	}
}

func intPtr(v int) *int {
	return &v
}

// IsShippingSubject returns true if the subject contains shipping keywords.
func IsShippingSubject(subject string) bool {
	return shippingPattern.MatchString(subject)
}

// ExtractLargeCharge extracts a dollar amount > 100 from the subject, or returns 0.
func ExtractLargeCharge(subject string) float64 {
	matches := largeChargePattern.FindAllStringSubmatch(subject, -1)
	for _, m := range matches {
		// Remove commas for parsing.
		cleaned := regexp.MustCompile(",").ReplaceAllString(m[1], "")
		amount, err := strconv.ParseFloat(cleaned, 64)
		if err != nil {
			continue
		}
		if amount > 100 {
			return math.Round(amount*100) / 100
		}
	}
	return 0
}
