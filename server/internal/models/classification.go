package models

// Classification category values.
const (
	ClassActionRequired = "action_required"
	ClassNewsletter     = "newsletter"
	ClassFiltered       = "filtered"
	ClassTransactional  = "transactional"
)

// ClassifiedBy source values.
const (
	ClassifiedByRules    = "rules"
	ClassifiedByFeatures = "features"
	ClassifiedByLLM      = "llm"
	ClassifiedByUser     = "user"
)

// Classification holds the classification result for an email.
type Classification struct {
	Classification string  `json:"classification"`
	Confidence     float64 `json:"confidence"`
	ClassifiedBy   string  `json:"classified_by"`
	Reason         string  `json:"reason,omitempty"`
	IsOverridden   bool    `json:"is_overridden"`
}

// ReclassifyRequest is the request body for overriding an email's classification.
type ReclassifyRequest struct {
	NewClassification string `json:"new_classification"`
	Confirm           bool   `json:"confirm"`
}

// ValidClassifications returns all valid classification values.
func ValidClassifications() []string {
	return []string{ClassActionRequired, ClassNewsletter, ClassFiltered, ClassTransactional}
}

// ValidClassifiedBy returns all valid classified_by values.
func ValidClassifiedBy() []string {
	return []string{ClassifiedByRules, ClassifiedByFeatures, ClassifiedByLLM, ClassifiedByUser}
}
