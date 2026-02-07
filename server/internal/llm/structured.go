package llm

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

// ErrMalformedResponse indicates the LLM returned unparseable output.
var ErrMalformedResponse = fmt.Errorf("malformed LLM response")

// classificationMap normalizes LLM classification labels to internal values.
var classificationMap = map[string]string{
	"action":          "action_required",
	"action_required": "action_required",
	"newsletter":      "newsletter",
	"filtered":        "filtered",
	"transactional":   "transactional",
}

// jsonBlockRe matches JSON inside markdown code blocks.
var jsonBlockRe = regexp.MustCompile("(?s)```(?:json)?\\s*\\n?(\\{.*?\\})\\s*```")

// classRe extracts classification from text when JSON parsing fails.
var classRe = regexp.MustCompile(`(?i)"?classification"?\s*[:=]\s*"?(ACTION|NEWSLETTER|FILTERED|TRANSACTIONAL)"?`)

// confRe extracts confidence from text when JSON parsing fails.
var confRe = regexp.MustCompile(`(?i)"?confidence"?\s*[:=]\s*"?([\d.]+)"?`)

// reasonRe extracts reasoning from text when JSON parsing fails.
var reasonRe = regexp.MustCompile(`(?i)"?reasoning"?\s*[:=]\s*"([^"]*)"`)

// ParseClassifyResponse attempts to parse a classification response from raw LLM text.
// It tries three strategies: strict JSON, JSON in code block, regex extraction.
func ParseClassifyResponse(raw string) (*ClassifyResponse, error) {
	raw = strings.TrimSpace(raw)

	// Strategy 1: strict JSON parse
	var resp ClassifyResponse
	if err := json.Unmarshal([]byte(raw), &resp); err == nil {
		if normalized, err := normalizeClassifyResponse(&resp); err == nil {
			return normalized, nil
		}
	}

	// Strategy 2: extract JSON from markdown code block
	if matches := jsonBlockRe.FindStringSubmatch(raw); len(matches) > 1 {
		if err := json.Unmarshal([]byte(matches[1]), &resp); err == nil {
			if normalized, err := normalizeClassifyResponse(&resp); err == nil {
				return normalized, nil
			}
		}
	}

	// Strategy 3: regex extraction of key fields
	classMatch := classRe.FindStringSubmatch(raw)
	if classMatch != nil {
		classification := strings.ToUpper(classMatch[1])
		confidence := 0.7 // default confidence for regex-extracted results
		reasoning := ""

		if confMatch := confRe.FindStringSubmatch(raw); confMatch != nil {
			if v, err := strconv.ParseFloat(confMatch[1], 64); err == nil && v >= 0 && v <= 1 {
				confidence = v
			}
		}
		if reasonMatch := reasonRe.FindStringSubmatch(raw); reasonMatch != nil {
			reasoning = reasonMatch[1]
		}

		resp := &ClassifyResponse{
			Classification: classification,
			Confidence:     confidence,
			Reasoning:      reasoning,
		}
		if normalized, err := normalizeClassifyResponse(resp); err == nil {
			return normalized, nil
		}
	}

	return nil, fmt.Errorf("%w: could not parse classification from: %.200s", ErrMalformedResponse, raw)
}

// normalizeClassifyResponse normalizes the classification label and validates the response.
func normalizeClassifyResponse(resp *ClassifyResponse) (*ClassifyResponse, error) {
	key := strings.ToLower(strings.TrimSpace(resp.Classification))
	normalized, ok := classificationMap[key]
	if !ok {
		return nil, fmt.Errorf("unknown classification: %s", resp.Classification)
	}
	resp.Classification = normalized

	if resp.Confidence < 0 {
		resp.Confidence = 0
	}
	if resp.Confidence > 1 {
		resp.Confidence = 1
	}

	return resp, nil
}

// ParseExtractResponse attempts to parse a recommendation extraction response.
func ParseExtractResponse(raw string) (*ExtractResponse, error) {
	raw = strings.TrimSpace(raw)

	// Strategy 1: strict JSON parse
	var resp ExtractResponse
	if err := json.Unmarshal([]byte(raw), &resp); err == nil {
		return &resp, nil
	}

	// Strategy 2: extract JSON from markdown code block
	if matches := jsonBlockRe.FindStringSubmatch(raw); len(matches) > 1 {
		if err := json.Unmarshal([]byte(matches[1]), &resp); err == nil {
			return &resp, nil
		}
	}

	// Strategy 3: try wrapping in object if it looks like a bare array
	arrayRe := regexp.MustCompile(`(?s)^\[.*\]$`)
	if arrayRe.MatchString(raw) {
		wrapped := `{"recommendations":` + raw + `}`
		if err := json.Unmarshal([]byte(wrapped), &resp); err == nil {
			return &resp, nil
		}
	}

	return nil, fmt.Errorf("%w: could not parse extraction from: %.200s", ErrMalformedResponse, raw)
}
