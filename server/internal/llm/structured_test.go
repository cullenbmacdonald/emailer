package llm

import (
	"errors"
	"testing"
)

func TestParseClassifyResponse_StrictJSON(t *testing.T) {
	raw := `{"classification": "ACTION", "confidence": 0.85, "reasoning": "contains a question"}`
	resp, err := ParseClassifyResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != "action_required" {
		t.Errorf("got %q, want action_required", resp.Classification)
	}
	if resp.Confidence != 0.85 {
		t.Errorf("got confidence %f, want 0.85", resp.Confidence)
	}
	if resp.Reasoning != "contains a question" {
		t.Errorf("got reasoning %q", resp.Reasoning)
	}
}

func TestParseClassifyResponse_LowercaseLabels(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{`{"classification":"newsletter","confidence":0.9,"reasoning":""}`, "newsletter"},
		{`{"classification":"filtered","confidence":0.8,"reasoning":""}`, "filtered"},
		{`{"classification":"transactional","confidence":0.95,"reasoning":""}`, "transactional"},
		{`{"classification":"action","confidence":0.7,"reasoning":""}`, "action_required"},
		{`{"classification":"action_required","confidence":0.7,"reasoning":""}`, "action_required"},
	}
	for _, tt := range tests {
		resp, err := ParseClassifyResponse(tt.input)
		if err != nil {
			t.Errorf("ParseClassifyResponse(%q) error: %v", tt.input, err)
			continue
		}
		if resp.Classification != tt.want {
			t.Errorf("ParseClassifyResponse(%q) = %q, want %q", tt.input, resp.Classification, tt.want)
		}
	}
}

func TestParseClassifyResponse_CodeBlock(t *testing.T) {
	raw := "Here is my analysis:\n```json\n{\"classification\": \"NEWSLETTER\", \"confidence\": 0.92, \"reasoning\": \"bulk email\"}\n```"
	resp, err := ParseClassifyResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != "newsletter" {
		t.Errorf("got %q, want newsletter", resp.Classification)
	}
}

func TestParseClassifyResponse_RegexFallback(t *testing.T) {
	raw := `Based on my analysis, classification: "ACTION", confidence: 0.75, reasoning: "direct question to recipient"`
	resp, err := ParseClassifyResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != "action_required" {
		t.Errorf("got %q, want action_required", resp.Classification)
	}
	if resp.Confidence != 0.75 {
		t.Errorf("got confidence %f, want 0.75", resp.Confidence)
	}
}

func TestParseClassifyResponse_RegexNoConfidence(t *testing.T) {
	raw := `classification: FILTERED`
	resp, err := ParseClassifyResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Classification != "filtered" {
		t.Errorf("got %q, want filtered", resp.Classification)
	}
	if resp.Confidence != 0.7 {
		t.Errorf("got confidence %f, want 0.7 (default)", resp.Confidence)
	}
}

func TestParseClassifyResponse_Malformed(t *testing.T) {
	_, err := ParseClassifyResponse("I don't know how to classify this email.")
	if err == nil {
		t.Fatal("expected error for malformed response")
	}
	if !errors.Is(err, ErrMalformedResponse) {
		t.Errorf("expected ErrMalformedResponse, got: %v", err)
	}
}

func TestParseClassifyResponse_UnknownClass(t *testing.T) {
	raw := `{"classification": "SPAM", "confidence": 0.9, "reasoning": "spam"}`
	_, err := ParseClassifyResponse(raw)
	if err == nil {
		t.Fatal("expected error for unknown classification")
	}
}

func TestParseClassifyResponse_ConfidenceClamp(t *testing.T) {
	raw := `{"classification": "ACTION", "confidence": 1.5, "reasoning": ""}`
	resp, err := ParseClassifyResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Confidence != 1.0 {
		t.Errorf("got confidence %f, want 1.0 (clamped)", resp.Confidence)
	}
}

func TestParseExtractResponse_StrictJSON(t *testing.T) {
	raw := `{"recommendations": [{"type": "book", "title": "Dune", "creator": "Frank Herbert", "context": "must read", "confidence": "high"}]}`
	resp, err := ParseExtractResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 1 {
		t.Fatalf("got %d recommendations, want 1", len(resp.Recommendations))
	}
	if resp.Recommendations[0].Title != "Dune" {
		t.Errorf("got title %q, want Dune", resp.Recommendations[0].Title)
	}
}

func TestParseExtractResponse_CodeBlock(t *testing.T) {
	raw := "```json\n{\"recommendations\": [{\"type\": \"podcast\", \"title\": \"Lex Fridman\", \"creator\": \"\", \"context\": \"great listen\", \"confidence\": \"medium\"}]}\n```"
	resp, err := ParseExtractResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 1 {
		t.Fatalf("got %d recommendations, want 1", len(resp.Recommendations))
	}
}

func TestParseExtractResponse_BareArray(t *testing.T) {
	raw := `[{"type": "article", "title": "Test", "creator": "", "context": "read this", "confidence": "low"}]`
	resp, err := ParseExtractResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 1 {
		t.Fatalf("got %d recommendations, want 1", len(resp.Recommendations))
	}
}

func TestParseExtractResponse_Empty(t *testing.T) {
	raw := `{"recommendations": []}`
	resp, err := ParseExtractResponse(raw)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(resp.Recommendations) != 0 {
		t.Errorf("got %d recommendations, want 0", len(resp.Recommendations))
	}
}

func TestParseExtractResponse_Malformed(t *testing.T) {
	_, err := ParseExtractResponse("No recommendations found in this email.")
	if err == nil {
		t.Fatal("expected error for malformed response")
	}
	if !errors.Is(err, ErrMalformedResponse) {
		t.Errorf("expected ErrMalformedResponse, got: %v", err)
	}
}
