package classifier

import (
	"context"
	"strings"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestExtractFeatures_ListUnsubscribe(t *testing.T) {
	input := &EmailInput{
		From:            models.Contact{Email: "news@example.com"},
		ListUnsubscribe: "<mailto:unsub@example.com>",
	}
	f := ExtractFeatures(context.Background(), input, nil)
	if !f.HasListUnsubscribe {
		t.Error("expected HasListUnsubscribe = true")
	}
}

func TestExtractFeatures_BulkHeaders(t *testing.T) {
	tests := []struct {
		name    string
		headers map[string]string
		want    bool
	}{
		{"precedence bulk", map[string]string{"precedence": "bulk"}, true},
		{"precedence list", map[string]string{"precedence": "list"}, true},
		{"precedence junk", map[string]string{"precedence": "junk"}, true},
		{"list-id present", map[string]string{"list-id": "<list.example.com>"}, true},
		{"no bulk headers", map[string]string{"from": "test"}, false},
		{"empty headers", map[string]string{}, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			input := &EmailInput{
				From:    models.Contact{Email: "sender@example.com"},
				Headers: tt.headers,
			}
			f := ExtractFeatures(context.Background(), input, nil)
			if f.HasBulkHeaders != tt.want {
				t.Errorf("HasBulkHeaders = %v, want %v", f.HasBulkHeaders, tt.want)
			}
		})
	}
}

func TestExtractFeatures_ActionPhrases(t *testing.T) {
	tests := []struct {
		text string
		want bool
	}{
		{"Can you review this?", true},
		{"Could you send the report?", true},
		{"Would you be able to help?", true},
		{"Let me know if that works", true},
		{"What do you think about this?", true},
		{"Are you available tomorrow?", true},
		{"Please review and approve", true},
		{"Action required: update your profile", true},
		{"This is urgent", true},
		{"Need this ASAP", true},
		{"Here is the newsletter", false},
		{"Your order has shipped", false},
	}

	for _, tt := range tests {
		t.Run(tt.text, func(t *testing.T) {
			input := &EmailInput{
				From:     models.Contact{Email: "sender@example.com"},
				TextBody: tt.text,
				Headers:  map[string]string{},
			}
			f := ExtractFeatures(context.Background(), input, nil)
			if f.HasActionPhrases != tt.want {
				t.Errorf("HasActionPhrases = %v, want %v", f.HasActionPhrases, tt.want)
			}
		})
	}
}

func TestExtractFeatures_DeadlineMention(t *testing.T) {
	tests := []struct {
		text string
		want bool
	}{
		{"Please submit by Friday", true},
		{"Deadline is next week", true},
		{"Due date: March 15", true},
		{"Expires on December 31", true},
		{"By end of day", true},
		{"By tomorrow", true},
		{"Here is the report", false},
	}

	for _, tt := range tests {
		t.Run(tt.text, func(t *testing.T) {
			input := &EmailInput{
				From:     models.Contact{Email: "sender@example.com"},
				TextBody: tt.text,
				Headers:  map[string]string{},
			}
			f := ExtractFeatures(context.Background(), input, nil)
			if f.HasDeadlineMention != tt.want {
				t.Errorf("HasDeadlineMention = %v, want %v for %q", f.HasDeadlineMention, tt.want, tt.text)
			}
		})
	}
}

func TestExtractFeatures_UnsubscribeText(t *testing.T) {
	tests := []struct {
		text string
		want bool
	}{
		{"Click here to unsubscribe from this list", true},
		{"Opt out of future emails", true},
		{"Manage your preferences", true},
		{"Update your email preferences", true},
		{"Thanks for reading", false},
	}

	for _, tt := range tests {
		t.Run(tt.text, func(t *testing.T) {
			input := &EmailInput{
				From:     models.Contact{Email: "sender@example.com"},
				TextBody: tt.text,
				Headers:  map[string]string{},
			}
			f := ExtractFeatures(context.Background(), input, nil)
			if f.HasUnsubscribeText != tt.want {
				t.Errorf("HasUnsubscribeText = %v, want %v", f.HasUnsubscribeText, tt.want)
			}
		})
	}
}

func TestExtractFeatures_NoReply(t *testing.T) {
	input := &EmailInput{
		From:    models.Contact{Email: "noreply@example.com"},
		Headers: map[string]string{},
	}
	f := ExtractFeatures(context.Background(), input, nil)
	if !f.IsNoReply {
		t.Error("expected IsNoReply = true")
	}
}

func TestExtractFeatures_SenderStats(t *testing.T) {
	stats := &mockSenderStats{
		replyRates: map[string]float64{"sender@example.com": 0.8},
		priorClass: map[string]string{"sender@example.com": models.ClassActionRequired},
	}

	input := &EmailInput{
		From:    models.Contact{Email: "sender@example.com"},
		Headers: map[string]string{},
	}
	f := ExtractFeatures(context.Background(), input, stats)
	if f.SenderReplyRate != 0.8 {
		t.Errorf("SenderReplyRate = %f, want 0.8", f.SenderReplyRate)
	}
	if f.SenderPriorClass != models.ClassActionRequired {
		t.Errorf("SenderPriorClass = %s, want action_required", f.SenderPriorClass)
	}
}

func TestFeaturesClassifier_ActionEmail(t *testing.T) {
	fc := NewFeaturesClassifier(nil, testLogger())
	input := &EmailInput{
		From:     models.Contact{Email: "colleague@work.com"},
		To:       []models.Contact{{Email: "me@work.com"}},
		Subject:  "Can you review this document?",
		TextBody: "Let me know what you think by Friday. Could you also send the updated numbers?",
		Headers:  map[string]string{},
	}
	result := fc.Classify(context.Background(), input)
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required", result.Classification)
	}
}

func TestFeaturesClassifier_NewsletterEmail(t *testing.T) {
	fc := NewFeaturesClassifier(nil, testLogger())
	input := &EmailInput{
		From:            models.Contact{Email: "digest@news.com"},
		To:              []models.Contact{{Email: "me@example.com"}},
		Subject:         "Weekly Tech Digest #42",
		TextBody:        "Here are this week's top stories..." + strings.Repeat(" link", 500) + "\nTo unsubscribe, click here.",
		HTMLBody:        strings.Repeat(`<a href="https://example.com">link</a>`, 15),
		ListUnsubscribe: "<mailto:unsub@news.com>",
		Headers:         map[string]string{"precedence": "bulk"},
	}
	result := fc.Classify(context.Background(), input)
	if result.Classification != models.ClassNewsletter {
		t.Errorf("got %s, want newsletter", result.Classification)
	}
}

func TestFeaturesClassifier_FilteredEmail(t *testing.T) {
	fc := NewFeaturesClassifier(nil, testLogger())
	input := &EmailInput{
		From:     models.Contact{Email: "noreply@marketing.example.com"},
		To:       []models.Contact{{Email: "undisclosed-recipients:;"}},
		CC:       make([]models.Contact, 20), // many recipients
		Subject:  "Special offer just for you!",
		TextBody: "Buy now! Limited time only.",
		Headers:  map[string]string{"precedence": "bulk"},
	}
	result := fc.Classify(context.Background(), input)
	if result.Classification != models.ClassFiltered {
		t.Errorf("got %s, want filtered", result.Classification)
	}
}

func TestFeaturesClassifier_ActionBias(t *testing.T) {
	// Verify that ActionBias is applied
	f := &Features{
		IsInToField:    true,
		RecipientCount: 1,
	}
	scores := scoreFeatures(f)
	actionScore := scores[models.ClassActionRequired]
	// Without bias it would be 2.0, with bias should be 2.4
	if actionScore != 2.0*ActionBias {
		t.Errorf("action score = %f, want %f", actionScore, 2.0*ActionBias)
	}
}

func TestFeaturesClassifier_NegativeScoresClamped(t *testing.T) {
	// No-reply with action phrases: action score should not go negative
	f := &Features{
		IsNoReply:      true,
		RecipientCount: 1,
	}
	scores := scoreFeatures(f)
	for class, score := range scores {
		if score < 0 {
			t.Errorf("score for %s is negative: %f", class, score)
		}
	}
}

func TestFeaturesClassifier_SenderPriorClassBoost(t *testing.T) {
	stats := &mockSenderStats{
		priorClass: map[string]string{"sender@example.com": models.ClassNewsletter},
	}
	fc := NewFeaturesClassifier(stats, testLogger())
	input := &EmailInput{
		From:     models.Contact{Email: "sender@example.com"},
		To:       []models.Contact{{Email: "me@example.com"}},
		Subject:  "Update from sender",
		TextBody: "Some content here.",
		Headers:  map[string]string{},
	}
	result := fc.Classify(context.Background(), input)
	// With a prior class of newsletter and 3.0 boost, newsletter should score well
	if result.Classification != models.ClassNewsletter {
		t.Errorf("got %s, want newsletter (prior class boost)", result.Classification)
	}
}
