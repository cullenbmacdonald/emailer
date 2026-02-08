package classifier

import (
	"context"
	"regexp"
	"strings"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// Known newsletter domains (List-Unsubscribe + from domain match).
var knownNewsletterDomains = map[string]bool{
	"substack.com":        true,
	"substackinc.com":     true,
	"beehiiv.com":         true,
	"mailchimp.com":       true,
	"convertkit.com":      true,
	"buttondown.email":    true,
	"revue.email":         true,
	"ghost.io":            true,
	"campaignmonitor.com": true,
	"sendinblue.com":      true,
	"constantcontact.com": true,
	"mailerlite.com":      true,
	"getresponse.com":     true,
	"drip.com":            true,
	"tinyletter.com":      true,
}

// Transactional subject patterns.
var transactionalPatterns = []*regexp.Regexp{
	// Order and shipping
	regexp.MustCompile(`(?i)\border\s+(confirm|receipt|ship|deliver|track)`),
	regexp.MustCompile(`(?i)\bshipping\s+(confirm|notif|update)`),
	regexp.MustCompile(`(?i)\b(has\s+shipped|out\s+for\s+delivery|was\s+delivered)`),
	regexp.MustCompile(`(?i)\btrack(ing)?\s+(number|your|order|package)`),
	// Receipts and payments
	regexp.MustCompile(`(?i)\b(receipt\s+for|payment\s+(confirm|received|processed))`),
	regexp.MustCompile(`(?i)\b(invoice|billing\s+statement)`),
	regexp.MustCompile(`(?i)\byour\s+(purchase|transaction)`),
	// Password and security
	regexp.MustCompile(`(?i)\b(password\s+reset|reset\s+(your\s+)?password)`),
	regexp.MustCompile(`(?i)\bverif(y|ication)\s+(your\s+)?(email|account|code|identity)`),
	regexp.MustCompile(`(?i)\b(security\s+(alert|code|notification)|two.factor|2fa|one.time\s+(code|password))`),
	regexp.MustCompile(`(?i)\bconfirm\s+your\s+(email|account|registration)`),
	// Calendar
	regexp.MustCompile(`(?i)\b(calendar\s+(invit|event)|invitation:\s+)`),
	regexp.MustCompile(`(?i)\b(accepted|declined|tentative):\s+`),
}

// No-reply address patterns.
var noReplyPatterns = []*regexp.Regexp{
	regexp.MustCompile(`(?i)^no[-_.]?reply@`),
	regexp.MustCompile(`(?i)^do[-_.]?not[-_.]?reply@`),
	regexp.MustCompile(`(?i)^noreply@`),
	regexp.MustCompile(`(?i)^mailer-daemon@`),
	regexp.MustCompile(`(?i)^postmaster@`),
	regexp.MustCompile(`(?i)^notifications?@`),
	regexp.MustCompile(`(?i)^alerts?@`),
	regexp.MustCompile(`(?i)^auto[-_.]?notify@`),
}

// RulesClassifier implements Layer 0 deterministic classification.
type RulesClassifier struct {
	vip    VIPChecker
	logger zerolog.Logger
}

// NewRulesClassifier creates a new rules classifier.
func NewRulesClassifier(vip VIPChecker, logger zerolog.Logger) *RulesClassifier {
	return &RulesClassifier{
		vip:    vip,
		logger: logger.With().Str("component", "classifier.rules").Logger(),
	}
}

// Classify applies deterministic rules. Returns nil if no rule matches.
func (r *RulesClassifier) Classify(ctx context.Context, input *EmailInput) *ClassificationResult {
	// Rule 1: VIP senders -> action_required
	if r.vip != nil {
		isVIP, err := r.vip.IsVIP(ctx, input.From.Email)
		if err != nil {
			r.logger.Warn().Err(err).Str("email", input.From.Email).Msg("VIP check failed")
		} else if isVIP {
			return &ClassificationResult{
				Classification: models.ClassActionRequired,
				Confidence:     1.0,
				ClassifiedBy:   models.ClassifiedByRules,
				Reason:         "VIP sender",
			}
		}
	}

	// Rule 2: Known newsletter domain -> newsletter
	// These domains exclusively send newsletters, so List-Unsubscribe is not required.
	if isKnownNewsletterDomain(input.From.Email) {
		reason := "known newsletter domain"
		conf := 0.95
		if input.ListUnsubscribe != "" {
			reason = "known newsletter domain with List-Unsubscribe"
			conf = 0.99
		}
		return &ClassificationResult{
			Classification: models.ClassNewsletter,
			Confidence:     conf,
			ClassifiedBy:   models.ClassifiedByRules,
			Reason:         reason,
		}
	}

	// Rule 3: Transactional subject patterns -> transactional
	if reason := matchesTransactionalPattern(input.Subject); reason != "" {
		return &ClassificationResult{
			Classification: models.ClassTransactional,
			Confidence:     0.95,
			ClassifiedBy:   models.ClassifiedByRules,
			Reason:         reason,
		}
	}

	// Rule 4: No-reply addresses pass through to features (not action)
	// This is handled implicitly: we return nil so features layer handles it.
	// The no-reply check is used in features to penalize action score.

	return nil
}

// isKnownNewsletterDomain checks if the sender's email comes from a known newsletter domain.
func isKnownNewsletterDomain(email string) bool {
	atIdx := strings.LastIndex(email, "@")
	if atIdx < 0 {
		return false
	}
	domain := strings.ToLower(email[atIdx+1:])

	// Check exact domain match
	if knownNewsletterDomains[domain] {
		return true
	}

	// Check if the domain is a subdomain of a known newsletter domain
	for d := range knownNewsletterDomains {
		if strings.HasSuffix(domain, "."+d) {
			return true
		}
	}
	return false
}

// matchesTransactionalPattern returns the matched pattern description, or empty string.
func matchesTransactionalPattern(subject string) string {
	for _, pat := range transactionalPatterns {
		if pat.MatchString(subject) {
			return "transactional pattern: " + pat.String()
		}
	}
	return ""
}

// IsNoReplyAddress checks if an email address is a no-reply/automated address.
func IsNoReplyAddress(email string) bool {
	lower := strings.ToLower(email)
	for _, pat := range noReplyPatterns {
		if pat.MatchString(lower) {
			return true
		}
	}
	return false
}
