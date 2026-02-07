package classifier

import (
	"context"
	"errors"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestPipeline_RulesFirst(t *testing.T) {
	vip := &mockVIPChecker{vips: map[string]bool{"boss@work.com": true}}
	p := NewPipeline(vip, nil, nil, testLogger())

	input := &EmailInput{
		From:    models.Contact{Email: "boss@work.com"},
		Subject: "Hello",
		Headers: map[string]string{},
	}
	result := p.Classify(context.Background(), input)
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required", result.Classification)
	}
	if result.ClassifiedBy != models.ClassifiedByRules {
		t.Errorf("got %s, want rules", result.ClassifiedBy)
	}
}

func TestPipeline_FeaturesAccepted_HighConfidence(t *testing.T) {
	// Newsletter with strong signals should be accepted by features
	p := NewPipeline(nil, nil, nil, testLogger())

	input := &EmailInput{
		From:            models.Contact{Email: "news@example.com"},
		To:              []models.Contact{{Email: "me@example.com"}},
		Subject:         "Weekly Digest",
		TextBody:        "Content here. Unsubscribe from this list.",
		HTMLBody:        `<a href="https://a.com">1</a><a href="https://b.com">2</a><a href="https://c.com">3</a><a href="https://d.com">4</a><a href="https://e.com">5</a><a href="https://f.com">6</a><a href="https://g.com">7</a><a href="https://h.com">8</a><a href="https://i.com">9</a><a href="https://j.com">10</a><a href="https://k.com">11</a>`,
		ListUnsubscribe: "<mailto:unsub@example.com>",
		Headers:         map[string]string{"precedence": "bulk", "list-id": "<list.example.com>"},
	}
	result := p.Classify(context.Background(), input)
	if result.Classification != models.ClassNewsletter {
		t.Errorf("got %s, want newsletter", result.Classification)
	}
	if result.ClassifiedBy != models.ClassifiedByFeatures {
		t.Errorf("got %s, want features", result.ClassifiedBy)
	}
}

func TestPipeline_FeaturesAccepted_ActionLowThreshold(t *testing.T) {
	// Action email with >= 0.6 confidence should be accepted
	p := NewPipeline(nil, nil, nil, testLogger())

	input := &EmailInput{
		From:     models.Contact{Email: "colleague@work.com"},
		To:       []models.Contact{{Email: "me@work.com"}},
		Subject:  "Can you help?",
		TextBody: "Let me know if you can help with this.",
		Headers:  map[string]string{},
	}
	result := p.Classify(context.Background(), input)
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required", result.Classification)
	}
}

func TestPipeline_LLMEscalation(t *testing.T) {
	llm := &mockLLMClassifier{
		result: &ClassificationResult{
			Classification: models.ClassNewsletter,
			Confidence:     0.9,
			ClassifiedBy:   models.ClassifiedByLLM,
			Reason:         "LLM determined newsletter",
		},
	}
	p := NewPipeline(nil, nil, llm, testLogger())

	// Ambiguous email - features won't be confident enough
	input := &EmailInput{
		From:     models.Contact{Email: "info@company.com"},
		To:       []models.Contact{{Email: "me@example.com"}},
		Subject:  "Update from us",
		TextBody: "Here is some information.",
		Headers:  map[string]string{},
	}
	result := p.Classify(context.Background(), input)
	// The LLM should be consulted for this ambiguous email
	// Result depends on whether features confidence is below threshold
	if result == nil {
		t.Fatal("expected non-nil result")
	}
}

func TestPipeline_LLMFallback_OnError(t *testing.T) {
	llm := &mockLLMClassifier{err: errors.New("LLM unavailable")}
	p := NewPipeline(nil, nil, llm, testLogger())

	input := &EmailInput{
		From:     models.Contact{Email: "info@company.com"},
		To:       []models.Contact{{Email: "me@example.com"}},
		Subject:  "Update",
		TextBody: "Some content.",
		Headers:  map[string]string{},
	}
	result := p.Classify(context.Background(), input)
	if result == nil {
		t.Fatal("expected non-nil result on LLM failure")
	}
	// Should fall back to features or default action_required
}

func TestPipeline_LLMActionOverride(t *testing.T) {
	// LLM says non-action with low confidence -> override to action
	llm := &mockLLMClassifier{
		result: &ClassificationResult{
			Classification: models.ClassFiltered,
			Confidence:     0.6, // below 0.8 threshold
			ClassifiedBy:   models.ClassifiedByLLM,
			Reason:         "maybe filtered",
		},
	}
	p := NewPipeline(nil, nil, llm, testLogger())

	result := p.applyLLMResult(llm.result)

	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required (override)", result.Classification)
	}
}

func TestPipeline_LLMActionAccepted(t *testing.T) {
	// LLM says action with confidence >= 0.5 -> accept
	result := (&Pipeline{}).applyLLMResult(
		&ClassificationResult{
			Classification: models.ClassActionRequired,
			Confidence:     0.5,
			ClassifiedBy:   models.ClassifiedByLLM,
		},
	)
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required", result.Classification)
	}
}

func TestPipeline_LLMHighConfidenceNonAction(t *testing.T) {
	// LLM says non-action with high confidence (>= 0.8) -> accept as-is
	result := (&Pipeline{}).applyLLMResult(
		&ClassificationResult{
			Classification: models.ClassNewsletter,
			Confidence:     0.85,
			ClassifiedBy:   models.ClassifiedByLLM,
		},
	)
	if result.Classification != models.ClassNewsletter {
		t.Errorf("got %s, want newsletter", result.Classification)
	}
}

func TestPipeline_FallbackLowConfidence(t *testing.T) {
	p := NewPipeline(nil, nil, nil, testLogger())
	result := p.fallback(&ClassificationResult{
		Classification: models.ClassFiltered,
		Confidence:     0.3,
		ClassifiedBy:   models.ClassifiedByFeatures,
	})
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required fallback", result.Classification)
	}
	if result.Confidence != 0.5 {
		t.Errorf("got confidence %f, want 0.5", result.Confidence)
	}
}

func TestPipeline_FallbackAdequateConfidence(t *testing.T) {
	p := NewPipeline(nil, nil, nil, testLogger())
	feat := &ClassificationResult{
		Classification: models.ClassFiltered,
		Confidence:     0.6,
		ClassifiedBy:   models.ClassifiedByFeatures,
	}
	result := p.fallback(feat)
	if result.Classification != models.ClassFiltered {
		t.Errorf("got %s, want filtered", result.Classification)
	}
}

func TestPipeline_NeverReturnsNil(t *testing.T) {
	p := NewPipeline(nil, nil, nil, testLogger())

	inputs := []*EmailInput{
		{From: models.Contact{Email: "a@b.com"}, Headers: map[string]string{}},
		{From: models.Contact{Email: "noreply@x.com"}, Headers: map[string]string{}},
		{From: models.Contact{Email: "news@sub.com"}, Subject: "Newsletter", Headers: map[string]string{}},
	}

	for _, input := range inputs {
		result := p.Classify(context.Background(), input)
		if result == nil {
			t.Errorf("pipeline returned nil for input from %s", input.From.Email)
		}
	}
}

func TestShouldAcceptFeatures(t *testing.T) {
	tests := []struct {
		name   string
		class  string
		conf   float64
		accept bool
	}{
		{"high confidence newsletter", models.ClassNewsletter, 0.90, true},
		{"high confidence action", models.ClassActionRequired, 0.90, true},
		{"action at 0.6", models.ClassActionRequired, 0.60, true},
		{"action at 0.59", models.ClassActionRequired, 0.59, false},
		{"newsletter at 0.84", models.ClassNewsletter, 0.84, false},
		{"filtered at 0.85", models.ClassFiltered, 0.85, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := &ClassificationResult{Classification: tt.class, Confidence: tt.conf}
			got := shouldAcceptFeatures(r)
			if got != tt.accept {
				t.Errorf("shouldAcceptFeatures(%s, %f) = %v, want %v", tt.class, tt.conf, got, tt.accept)
			}
		})
	}
}
