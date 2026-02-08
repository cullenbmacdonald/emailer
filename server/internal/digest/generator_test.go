package digest

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// mockDataSource implements DataSource for testing.
type mockDataSource struct {
	actionQueueFn        func(ctx context.Context) (int, []models.AccountCount, error)
	returningTodayFn     func(ctx context.Context, date time.Time) ([]DigestSnoozeItem, error)
	readingQueueCountFn  func(ctx context.Context) (int, error)
	borderlineFilteredFn func(ctx context.Context, limit int, threshold float64) ([]DigestBorderlineItem, error)
	notableTransFn       func(ctx context.Context, since time.Time) ([]DigestTransactionalItem, error)
	todayStatsFn         func(ctx context.Context, since time.Time) (int, int, error)
	newslettersTodayFn   func(ctx context.Context, since time.Time) ([]DigestNewsletterItem, error)
	snoozeNudgesFn       func(ctx context.Context, min int) ([]DigestSnoozeNudge, error)
}

func (m *mockDataSource) ActionQueueSummary(ctx context.Context) (int, []models.AccountCount, error) {
	if m.actionQueueFn != nil {
		return m.actionQueueFn(ctx)
	}
	return 0, nil, nil
}

func (m *mockDataSource) ReturningToday(ctx context.Context, date time.Time) ([]DigestSnoozeItem, error) {
	if m.returningTodayFn != nil {
		return m.returningTodayFn(ctx, date)
	}
	return nil, nil
}

func (m *mockDataSource) ReadingQueueCount(ctx context.Context) (int, error) {
	if m.readingQueueCountFn != nil {
		return m.readingQueueCountFn(ctx)
	}
	return 0, nil
}

func (m *mockDataSource) BorderlineFiltered(ctx context.Context, limit int, threshold float64) ([]DigestBorderlineItem, error) {
	if m.borderlineFilteredFn != nil {
		return m.borderlineFilteredFn(ctx, limit, threshold)
	}
	return nil, nil
}

func (m *mockDataSource) NotableTransactional(ctx context.Context, since time.Time) ([]DigestTransactionalItem, error) {
	if m.notableTransFn != nil {
		return m.notableTransFn(ctx, since)
	}
	return nil, nil
}

func (m *mockDataSource) TodayStats(ctx context.Context, since time.Time) (int, int, error) {
	if m.todayStatsFn != nil {
		return m.todayStatsFn(ctx, since)
	}
	return 0, 0, nil
}

func (m *mockDataSource) NewslettersToday(ctx context.Context, since time.Time) ([]DigestNewsletterItem, error) {
	if m.newslettersTodayFn != nil {
		return m.newslettersTodayFn(ctx, since)
	}
	return nil, nil
}

func (m *mockDataSource) SnoozeNudges(ctx context.Context, min int) ([]DigestSnoozeNudge, error) {
	if m.snoozeNudgesFn != nil {
		return m.snoozeNudgesFn(ctx, min)
	}
	return nil, nil
}

// mockSaver implements DigestSaver for testing.
type mockSaver struct {
	saveFn      func(ctx context.Context, d *models.DailyDigest) (*models.DailyDigest, error)
	getLatestFn func(ctx context.Context, digestType string) (*models.DailyDigest, error)
}

func (m *mockSaver) SaveDigest(ctx context.Context, d *models.DailyDigest) (*models.DailyDigest, error) {
	if m.saveFn != nil {
		return m.saveFn(ctx, d)
	}
	d.ID = "digest-001"
	d.GeneratedAt = time.Now().UTC()
	return d, nil
}

func (m *mockSaver) GetLatestDigest(ctx context.Context, digestType string) (*models.DailyDigest, error) {
	if m.getLatestFn != nil {
		return m.getLatestFn(ctx, digestType)
	}
	return nil, errors.New("no digest found")
}

// mockBroadcaster implements Broadcaster for testing.
type mockBroadcaster struct {
	events []broadcastCall
}

type broadcastCall struct {
	eventType string
	payload   any
}

func (m *mockBroadcaster) BroadcastEvent(eventType string, payload any) {
	m.events = append(m.events, broadcastCall{eventType, payload})
}

func TestGenerateMorningDigest(t *testing.T) {
	data := &mockDataSource{
		actionQueueFn: func(_ context.Context) (int, []models.AccountCount, error) {
			return 5, []models.AccountCount{
				{AccountID: "a1", AccountName: "Work", AccountColor: "#ff0000", Count: 3},
				{AccountID: "a2", AccountName: "Personal", AccountColor: "#00ff00", Count: 2},
			}, nil
		},
		returningTodayFn: func(_ context.Context, _ time.Time) ([]DigestSnoozeItem, error) {
			return []DigestSnoozeItem{
				{EmailID: "e1", Subject: "Meeting", From: "Bob", ReturnAt: time.Now()},
			}, nil
		},
		readingQueueCountFn: func(_ context.Context) (int, error) {
			return 12, nil
		},
		borderlineFilteredFn: func(_ context.Context, _ int, _ float64) ([]DigestBorderlineItem, error) {
			return []DigestBorderlineItem{
				{EmailID: "e2", Subject: "Promo", From: "Store", Confidence: 0.72, Reason: "marketing language"},
			}, nil
		},
		notableTransFn: func(_ context.Context, _ time.Time) ([]DigestTransactionalItem, error) {
			return []DigestTransactionalItem{
				{EmailID: "e3", Subject: "Your order shipped", From: "Amazon", HighlightType: "shipping", DisplayText: "Your order shipped"},
			}, nil
		},
	}

	saver := &mockSaver{}
	bc := &mockBroadcaster{}
	gen := NewGenerator(data, saver, bc)

	now := time.Date(2025, 1, 15, 6, 0, 0, 0, time.UTC)
	digest, err := gen.Generate(context.Background(), models.DigestTypeMorning, now)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if digest.DigestType != models.DigestTypeMorning {
		t.Errorf("got type %s, want %s", digest.DigestType, models.DigestTypeMorning)
	}

	// Should have 5 morning sections.
	if len(digest.Sections) != 5 {
		t.Fatalf("got %d sections, want 5", len(digest.Sections))
	}

	// Verify section types in order.
	expectedTypes := []string{
		"action_queue_summary",
		"returning_today",
		"reading_queue_summary",
		"borderline_items",
		"notable_transactional",
	}
	for i, expected := range expectedTypes {
		if digest.Sections[i].Type != expected {
			t.Errorf("section[%d]: got type %s, want %s", i, digest.Sections[i].Type, expected)
		}
	}

	// Verify action_queue_summary details.
	aq := digest.Sections[0]
	if *aq.Count != 5 {
		t.Errorf("action_queue count: got %d, want 5", *aq.Count)
	}
	if len(aq.AccountBreakdown) != 2 {
		t.Errorf("action_queue breakdown: got %d accounts, want 2", len(aq.AccountBreakdown))
	}

	// Verify broadcast.
	if len(bc.events) != 1 {
		t.Fatalf("got %d broadcasts, want 1", len(bc.events))
	}
	if bc.events[0].eventType != models.WSEventDigestAvailable {
		t.Errorf("broadcast type: got %s, want %s", bc.events[0].eventType, models.WSEventDigestAvailable)
	}
}

func TestGenerateEveningDigest(t *testing.T) {
	data := &mockDataSource{
		todayStatsFn: func(_ context.Context, _ time.Time) (int, int, error) {
			return 15, 3, nil
		},
		actionQueueFn: func(_ context.Context) (int, []models.AccountCount, error) {
			return 2, nil, nil
		},
		newslettersTodayFn: func(_ context.Context, _ time.Time) ([]DigestNewsletterItem, error) {
			return []DigestNewsletterItem{
				{EmailID: "e4", NewsletterName: "Tech Digest", Subject: "Weekly roundup"},
			}, nil
		},
		snoozeNudgesFn: func(_ context.Context, _ int) ([]DigestSnoozeNudge, error) {
			return []DigestSnoozeNudge{
				{EmailID: "e5", Subject: "Follow up", From: "Client", SnoozeCount: 4, DaysSinceFirstSnooze: 12},
			}, nil
		},
	}

	saver := &mockSaver{}
	gen := NewGenerator(data, saver, nil) // nil broadcaster to test nil safety

	now := time.Date(2025, 1, 15, 19, 0, 0, 0, time.UTC)
	digest, err := gen.Generate(context.Background(), models.DigestTypeEvening, now)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if digest.DigestType != models.DigestTypeEvening {
		t.Errorf("got type %s, want %s", digest.DigestType, models.DigestTypeEvening)
	}

	// Should have 4 evening sections (no notable_transactional since mock returns nil).
	if len(digest.Sections) != 4 {
		t.Fatalf("got %d sections, want 4", len(digest.Sections))
	}

	expectedTypes := []string{
		"today_stats",
		"still_pending",
		"newsletters_today",
		"snooze_nudges",
	}
	for i, expected := range expectedTypes {
		if digest.Sections[i].Type != expected {
			t.Errorf("section[%d]: got type %s, want %s", i, digest.Sections[i].Type, expected)
		}
	}

	// Verify today_stats.
	ts := digest.Sections[0]
	if *ts.ArchivedCount != 15 {
		t.Errorf("archived count: got %d, want 15", *ts.ArchivedCount)
	}
	if *ts.SentCount != 3 {
		t.Errorf("sent count: got %d, want 3", *ts.SentCount)
	}

	// Verify snooze_nudges item.
	sn := digest.Sections[3]
	if len(sn.Items) != 1 {
		t.Fatalf("snooze nudges items: got %d, want 1", len(sn.Items))
	}
	if *sn.Items[0].SnoozeCount != 4 {
		t.Errorf("snooze count: got %d, want 4", *sn.Items[0].SnoozeCount)
	}
}

func TestGenerateEmptySectionsOmitted(t *testing.T) {
	data := &mockDataSource{} // All return empty/zero
	saver := &mockSaver{}
	gen := NewGenerator(data, saver, nil)

	now := time.Date(2025, 1, 15, 6, 0, 0, 0, time.UTC)
	digest, err := gen.Generate(context.Background(), models.DigestTypeMorning, now)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(digest.Sections) != 0 {
		t.Errorf("expected 0 sections for empty data, got %d", len(digest.Sections))
	}
}

func TestGenerateErrorsInSectionsLogButContinue(t *testing.T) {
	data := &mockDataSource{
		actionQueueFn: func(_ context.Context) (int, []models.AccountCount, error) {
			return 0, nil, errors.New("db error")
		},
		readingQueueCountFn: func(_ context.Context) (int, error) {
			return 7, nil
		},
	}
	saver := &mockSaver{}
	gen := NewGenerator(data, saver, nil)

	now := time.Date(2025, 1, 15, 6, 0, 0, 0, time.UTC)
	digest, err := gen.Generate(context.Background(), models.DigestTypeMorning, now)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// action_queue_summary should be skipped due to error; reading_queue should still appear.
	if len(digest.Sections) != 1 {
		t.Fatalf("got %d sections, want 1", len(digest.Sections))
	}
	if digest.Sections[0].Type != "reading_queue_summary" {
		t.Errorf("got section type %s, want reading_queue_summary", digest.Sections[0].Type)
	}
}

func TestGenerateInvalidType(t *testing.T) {
	gen := NewGenerator(&mockDataSource{}, &mockSaver{}, nil)
	_, err := gen.Generate(context.Background(), "unknown", time.Now())
	if err == nil {
		t.Error("expected error for unknown digest type")
	}
}

func TestIsShippingSubject(t *testing.T) {
	tests := []struct {
		subject string
		want    bool
	}{
		{"Your order has shipped", true},
		{"Out for delivery: package #123", true},
		{"Tracking update for your order", true},
		{"Your package is in transit", true},
		{"Your item has been delivered", true},
		{"Meeting tomorrow at 3pm", false},
		{"Newsletter: weekly update", false},
	}

	for _, tt := range tests {
		got := IsShippingSubject(tt.subject)
		if got != tt.want {
			t.Errorf("IsShippingSubject(%q) = %v, want %v", tt.subject, got, tt.want)
		}
	}
}

func TestExtractLargeCharge(t *testing.T) {
	tests := []struct {
		subject string
		want    float64
	}{
		{"Your receipt for $250.00", 250.00},
		{"Charge of $1,500.99 to your card", 1500.99},
		{"Payment of $50.00 processed", 0},       // Under threshold.
		{"No dollar amount here", 0},             // No match.
		{"$99.99 charge", 0},                     // Under 100.
		{"$100.01 charge", 100.01},               // Just over.
		{"Multiple: $50.00 and $200.00", 200.00}, // Returns first > 100.
	}

	for _, tt := range tests {
		got := ExtractLargeCharge(tt.subject)
		if got != tt.want {
			t.Errorf("ExtractLargeCharge(%q) = %v, want %v", tt.subject, got, tt.want)
		}
	}
}
