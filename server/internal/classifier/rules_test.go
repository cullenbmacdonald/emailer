package classifier

import (
	"context"
	"testing"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestRulesClassifier_VIPSender(t *testing.T) {
	vip := &mockVIPChecker{vips: map[string]bool{"boss@company.com": true}}
	rc := NewRulesClassifier(vip, testLogger())

	input := &EmailInput{
		From:    models.Contact{Email: "boss@company.com"},
		Subject: "Hey",
	}
	result := rc.Classify(context.Background(), input)
	if result == nil {
		t.Fatal("expected classification for VIP sender")
	}
	if result.Classification != models.ClassActionRequired {
		t.Errorf("got %s, want action_required", result.Classification)
	}
	if result.Confidence != 1.0 {
		t.Errorf("got confidence %f, want 1.0", result.Confidence)
	}
	if result.ClassifiedBy != models.ClassifiedByRules {
		t.Errorf("got classified_by %s, want rules", result.ClassifiedBy)
	}
}

func TestRulesClassifier_NewsletterDomain(t *testing.T) {
	rc := NewRulesClassifier(nil, testLogger())

	tests := []struct {
		name            string
		from            string
		listUnsubscribe string
		wantMatch       bool
		wantConfidence  float64
	}{
		{"substack with unsubscribe", "news@substack.com", "<mailto:unsub>", true, 0.99},
		{"substack subdomain", "news@letters.substack.com", "<mailto:unsub>", true, 0.99},
		{"substack without unsubscribe", "news@substack.com", "", true, 0.95},
		{"unknown domain with unsubscribe", "news@example.com", "<mailto:unsub>", false, 0},
		{"beehiiv", "digest@beehiiv.com", "<mailto:unsub>", true, 0.99},
		{"mailchimp subdomain", "noreply@mail.mailchimp.com", "<mailto:unsub>", true, 0.99},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			input := &EmailInput{
				From:            models.Contact{Email: tt.from},
				ListUnsubscribe: tt.listUnsubscribe,
				Subject:         "Weekly digest",
			}
			result := rc.Classify(context.Background(), input)
			if tt.wantMatch {
				if result == nil {
					t.Fatal("expected newsletter classification")
				}
				if result.Classification != models.ClassNewsletter {
					t.Errorf("got %s, want newsletter", result.Classification)
				}
				if result.Confidence != tt.wantConfidence {
					t.Errorf("got confidence %f, want %f", result.Confidence, tt.wantConfidence)
				}
			} else if result != nil && result.Classification == models.ClassNewsletter {
				t.Error("did not expect newsletter classification")
			}
		})
	}
}

func TestRulesClassifier_TransactionalPatterns(t *testing.T) {
	rc := NewRulesClassifier(nil, testLogger())

	tests := []struct {
		subject   string
		wantMatch bool
	}{
		{"Your order confirmation #12345", true},
		{"Order shipped - tracking info inside", true},
		{"Your package has shipped", true},
		{"Your package was delivered", true},
		{"Shipping confirmation for your order", true},
		{"Tracking your package", true},
		{"Receipt for your purchase", true},
		{"Payment confirmation", true},
		{"Payment received", true},
		{"Your purchase from Amazon", true},
		{"Reset your password", true},
		{"Password reset request", true},
		{"Verify your email address", true},
		{"Verification code: 123456", true},
		{"Security alert for your account", true},
		{"Your one-time password", true},
		{"Confirm your email address", true},
		{"Invitation: Team meeting", true},
		{"Accepted: Team standup", true},
		{"Hey, want to grab lunch?", false},
		{"Quarterly newsletter", false},
		{"Great article about shipping containers", false},
	}

	for _, tt := range tests {
		t.Run(tt.subject, func(t *testing.T) {
			input := &EmailInput{
				From:    models.Contact{Email: "sender@example.com"},
				Subject: tt.subject,
			}
			result := rc.Classify(context.Background(), input)
			if tt.wantMatch {
				if result == nil {
					t.Fatal("expected transactional classification")
				}
				if result.Classification != models.ClassTransactional {
					t.Errorf("got %s, want transactional", result.Classification)
				}
			} else if result != nil && result.Classification == models.ClassTransactional {
				t.Errorf("did not expect transactional for: %s", tt.subject)
			}
		})
	}
}

func TestRulesClassifier_NoMatchReturnsNil(t *testing.T) {
	rc := NewRulesClassifier(nil, testLogger())
	input := &EmailInput{
		From:    models.Contact{Email: "friend@gmail.com"},
		Subject: "Hey how are you?",
	}
	result := rc.Classify(context.Background(), input)
	if result != nil {
		t.Errorf("expected nil for ambiguous email, got %+v", result)
	}
}

func TestRulesClassifier_VIPPriority(t *testing.T) {
	// VIP should win even if subject matches transactional
	vip := &mockVIPChecker{vips: map[string]bool{"boss@company.com": true}}
	rc := NewRulesClassifier(vip, testLogger())

	input := &EmailInput{
		From:    models.Contact{Email: "boss@company.com"},
		Subject: "Your order confirmation",
	}
	result := rc.Classify(context.Background(), input)
	if result == nil || result.Classification != models.ClassActionRequired {
		t.Error("VIP should take priority over transactional pattern")
	}
}

func TestIsNoReplyAddress(t *testing.T) {
	tests := []struct {
		email string
		want  bool
	}{
		{"noreply@example.com", true},
		{"no-reply@example.com", true},
		{"no_reply@example.com", true},
		{"do-not-reply@example.com", true},
		{"donotreply@example.com", true},
		{"notifications@example.com", true},
		{"alerts@example.com", true},
		{"mailer-daemon@example.com", true},
		{"postmaster@example.com", true},
		{"john@example.com", false},
		{"sales@company.com", false},
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			got := IsNoReplyAddress(tt.email)
			if got != tt.want {
				t.Errorf("IsNoReplyAddress(%s) = %v, want %v", tt.email, got, tt.want)
			}
		})
	}
}

func TestIsKnownNewsletterDomain(t *testing.T) {
	tests := []struct {
		email string
		want  bool
	}{
		{"news@substack.com", true},
		{"news@mail.substack.com", true},
		{"news@beehiiv.com", true},
		{"news@example.com", false},
		{"news@gmail.com", false},
	}

	for _, tt := range tests {
		t.Run(tt.email, func(t *testing.T) {
			got := isKnownNewsletterDomain(tt.email)
			if got != tt.want {
				t.Errorf("isKnownNewsletterDomain(%s) = %v, want %v", tt.email, got, tt.want)
			}
		})
	}
}
