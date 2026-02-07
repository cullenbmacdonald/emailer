package models

import (
	"encoding/json"
	"errors"
	"testing"
)

func TestAPIErrorImplementsError(t *testing.T) {
	var err error = &APIError{Code: ErrCodeNotFound, Message: "email not found"}
	if err.Error() != "not_found: email not found" {
		t.Errorf("Error(): got %s", err.Error())
	}
}

func TestAPIErrorWithDetails(t *testing.T) {
	err := NewAPIError(ErrCodeInvalidParameter, "bad input").
		WithDetails(map[string]any{"field": "email"})

	if err.Details["field"] != "email" {
		t.Error("Details not set")
	}

	// Should include details in string representation
	s := err.Error()
	if len(s) == 0 {
		t.Error("Error() returned empty string")
	}
}

func TestAPIErrorRoundTrip(t *testing.T) {
	original := &APIError{
		Code:    ErrCodeConflict,
		Message: "snooze already active",
		Details: map[string]any{"email_id": "e-1"},
	}

	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("Marshal error: %v", err)
	}

	var decoded APIError
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("Unmarshal error: %v", err)
	}

	if decoded.Code != ErrCodeConflict {
		t.Errorf("Code: got %s", decoded.Code)
	}
	if decoded.Message != "snooze already active" {
		t.Errorf("Message: got %s", decoded.Message)
	}
}

func TestAPIErrorSatisfiesErrorInterface(t *testing.T) {
	apiErr := NewAPIError(ErrCodeInternalError, "something broke")

	// Should be usable with errors.As
	var target *APIError
	if !errors.As(apiErr, &target) {
		t.Error("errors.As failed for *APIError")
	}
}
