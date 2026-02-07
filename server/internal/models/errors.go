package models

import "fmt"

// Standard error codes matching the API spec.
const (
	ErrCodeInvalidParameter = "invalid_parameter"
	ErrCodeNotFound         = "not_found"
	ErrCodeUnauthorized     = "unauthorized"
	ErrCodeConflict         = "conflict"
	ErrCodeInternalError    = "internal_error"
)

// APIError is the standard error response format from the API spec.
type APIError struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`
}

// Error implements the error interface.
func (e *APIError) Error() string {
	if e.Details != nil {
		return fmt.Sprintf("%s: %s (%v)", e.Code, e.Message, e.Details)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

// NewAPIError creates an APIError with code and message.
func NewAPIError(code, message string) *APIError {
	return &APIError{Code: code, Message: message}
}

// WithDetails adds details to an APIError and returns it for chaining.
func (e *APIError) WithDetails(details map[string]any) *APIError {
	e.Details = details
	return e
}
