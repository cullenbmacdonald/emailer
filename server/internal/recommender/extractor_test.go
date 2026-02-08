package recommender

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/llm"
	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog"
)

// mockRecStore is a test double for RecommendationStore.
type mockRecStore struct {
	createFn       func(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error)
	findSimilarFn  func(ctx context.Context, title, recType string) (*models.Recommendation, error)
	incrementFn    func(ctx context.Context, id string) error
	addDupSourceFn func(ctx context.Context, recID, emailID, name, snippet string, date time.Time) error
}

func (m *mockRecStore) CreateRecommendation(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error) {
	if m.createFn != nil {
		return m.createFn(ctx, r)
	}
	r.ID = "rec-123"
	r.CreatedAt = time.Now()
	return r, nil
}

func (m *mockRecStore) FindSimilarRecommendation(ctx context.Context, title, recType string) (*models.Recommendation, error) {
	if m.findSimilarFn != nil {
		return m.findSimilarFn(ctx, title, recType)
	}
	return nil, errors.New("find similar recommendation: no rows in result set")
}

func (m *mockRecStore) IncrementDuplicateCount(ctx context.Context, id string) error {
	if m.incrementFn != nil {
		return m.incrementFn(ctx, id)
	}
	return nil
}

func (m *mockRecStore) AddDuplicateSource(ctx context.Context, recID, emailID, name, snippet string, date time.Time) error {
	if m.addDupSourceFn != nil {
		return m.addDupSourceFn(ctx, recID, emailID, name, snippet, date)
	}
	return nil
}

// mockEmailUpdater is a test double for EmailUpdater.
type mockEmailUpdater struct {
	updateFn func(ctx context.Context, emailID string, count int) error
}

func (m *mockEmailUpdater) UpdateRecommendationCount(ctx context.Context, emailID string, count int) error {
	if m.updateFn != nil {
		return m.updateFn(ctx, emailID, count)
	}
	return nil
}

// mockBroadcaster is a test double for Broadcaster.
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

func testInput() EmailInput {
	return EmailInput{
		EmailID:     "email-001",
		AccountID:   "acct-001",
		Subject:     "Weekly Newsletter",
		FromName:    "Tech Weekly",
		FromAddress: "tech@weekly.com",
		TextBody:    "Check out this great book: Thinking Fast and Slow by Daniel Kahneman.",
		ReceivedAt:  time.Now(),
	}
}

func TestExtract_NewRecommendations(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{
						Type:       "book",
						Title:      "Thinking Fast and Slow",
						Creator:    "Daniel Kahneman",
						Context:    "Check out this great book",
						Confidence: "high",
					},
				},
			}, nil
		},
	}

	store := &mockRecStore{}
	emailStore := &mockEmailUpdater{}
	broadcaster := &mockBroadcaster{}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, emailStore, broadcaster, logger)
	newCount, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newCount != 1 {
		t.Errorf("got newCount=%d, want 1", newCount)
	}
	if len(broadcaster.events) != 1 {
		t.Fatalf("got %d events, want 1", len(broadcaster.events))
	}
	if broadcaster.events[0].eventType != models.WSEventRecommendationNew {
		t.Errorf("got event type %q, want %q", broadcaster.events[0].eventType, models.WSEventRecommendationNew)
	}
}

func TestExtract_Duplicate(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{
						Type:       "book",
						Title:      "Thinking Fast and Slow",
						Creator:    "Daniel Kahneman",
						Context:    "A great book",
						Confidence: "high",
					},
				},
			}, nil
		},
	}

	incrementCalled := false
	dupSourceCalled := false
	store := &mockRecStore{
		findSimilarFn: func(_ context.Context, _, _ string) (*models.Recommendation, error) {
			return &models.Recommendation{
				ID:    "existing-rec",
				Title: "Thinking Fast and Slow",
				Type:  "book",
			}, nil
		},
		incrementFn: func(_ context.Context, id string) error {
			incrementCalled = true
			if id != "existing-rec" {
				t.Errorf("increment called with id=%q, want existing-rec", id)
			}
			return nil
		},
		addDupSourceFn: func(_ context.Context, recID, _, _, _ string, _ time.Time) error {
			dupSourceCalled = true
			if recID != "existing-rec" {
				t.Errorf("addDupSource called with recID=%q, want existing-rec", recID)
			}
			return nil
		},
	}

	broadcaster := &mockBroadcaster{}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, broadcaster, logger)
	newCount, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newCount != 0 {
		t.Errorf("got newCount=%d, want 0 (duplicate)", newCount)
	}
	if !incrementCalled {
		t.Error("IncrementDuplicateCount was not called")
	}
	if !dupSourceCalled {
		t.Error("AddDuplicateSource was not called")
	}
	if len(broadcaster.events) != 0 {
		t.Errorf("got %d broadcast events, want 0 for duplicate", len(broadcaster.events))
	}
}

func TestExtract_NoRecommendations(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{Recommendations: nil}, nil
		},
	}

	store := &mockRecStore{}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, nil, logger)
	newCount, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newCount != 0 {
		t.Errorf("got newCount=%d, want 0", newCount)
	}
}

func TestExtract_LLMError(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return nil, errors.New("LLM connection failed")
		},
	}

	store := &mockRecStore{}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, nil, logger)
	_, err := ext.Extract(context.Background(), testInput())
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestExtract_LowConfidenceSkipped(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{
						Type:       "book",
						Title:      "Some Book",
						Creator:    "Someone",
						Context:    "mentioned in passing",
						Confidence: "low",
					},
				},
			}, nil
		},
	}

	createCalled := false
	store := &mockRecStore{
		createFn: func(_ context.Context, _ *models.Recommendation) (*models.Recommendation, error) {
			createCalled = true
			return nil, nil
		},
	}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, nil, logger)
	newCount, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if newCount != 0 {
		t.Errorf("got newCount=%d, want 0 (low confidence skipped)", newCount)
	}
	if createCalled {
		t.Error("CreateRecommendation should not be called for low-confidence items")
	}
}

func TestExtract_EmptyTitleSkipped(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{Type: "book", Title: "", Creator: "", Context: "", Confidence: "high"},
				},
			}, nil
		},
	}

	createCalled := false
	store := &mockRecStore{
		createFn: func(_ context.Context, _ *models.Recommendation) (*models.Recommendation, error) {
			createCalled = true
			return nil, nil
		},
	}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, nil, logger)
	_, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if createCalled {
		t.Error("CreateRecommendation should not be called for empty title")
	}
}

func TestExtract_UnknownTypeDefaultsToOther(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{Type: "gadget", Title: "Some Gadget", Creator: "", Context: "cool gadget", Confidence: "high"},
				},
			}, nil
		},
	}

	var createdType string
	store := &mockRecStore{
		createFn: func(_ context.Context, r *models.Recommendation) (*models.Recommendation, error) {
			createdType = r.Type
			r.ID = "rec-new"
			r.CreatedAt = time.Now()
			return r, nil
		},
	}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, &mockBroadcaster{}, logger)
	_, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if createdType != models.RecTypeOther {
		t.Errorf("got type=%q, want %q", createdType, models.RecTypeOther)
	}
}

func TestExtract_MovieTvMappedToMovie(t *testing.T) {
	provider := &llm.MockProvider{
		ExtractRecommendationsFunc: func(_ context.Context, _ llm.ExtractRequest) (*llm.ExtractResponse, error) {
			return &llm.ExtractResponse{
				Recommendations: []llm.ExtractedRecommendation{
					{Type: "movie_tv", Title: "Some Show", Creator: "", Context: "great show", Confidence: "high"},
				},
			}, nil
		},
	}

	var createdType string
	store := &mockRecStore{
		createFn: func(_ context.Context, r *models.Recommendation) (*models.Recommendation, error) {
			createdType = r.Type
			r.ID = "rec-new"
			r.CreatedAt = time.Now()
			return r, nil
		},
	}
	logger := zerolog.Nop()

	ext := NewExtractor(provider, store, nil, &mockBroadcaster{}, logger)
	_, err := ext.Extract(context.Background(), testInput())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if createdType != models.RecTypeMovie {
		t.Errorf("got type=%q, want %q", createdType, models.RecTypeMovie)
	}
}
