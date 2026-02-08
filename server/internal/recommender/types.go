package recommender

import "github.com/cullenbmacdonald/emailer/internal/models"

// llmTypeMap maps LLM output type strings to internal model constants.
// The LLM prompt uses "movie_tv" but the DB schema has separate "movie" and "tv".
var llmTypeMap = map[string]string{
	"book":     models.RecTypeBook,
	"movie_tv": models.RecTypeMovie,
	"movie":    models.RecTypeMovie,
	"tv":       models.RecTypeTV,
	"music":    models.RecTypeMusic,
	"article":  models.RecTypeArticle,
	"podcast":  models.RecTypePodcast,
	"other":    models.RecTypeOther,
}

// NormalizeLLMType converts an LLM-output type string to a valid model type.
// Returns the normalized type and true if valid, or ("other", false) if unknown.
func NormalizeLLMType(llmType string) (string, bool) {
	if t, ok := llmTypeMap[llmType]; ok {
		return t, true
	}
	return models.RecTypeOther, false
}

// validConfidences is the set of valid LLM confidence labels.
var validConfidences = map[string]bool{
	"high":   true,
	"medium": true,
	"low":    true,
}

// IsValidConfidence checks if the confidence label from the LLM is valid.
func IsValidConfidence(c string) bool {
	return validConfidences[c]
}
