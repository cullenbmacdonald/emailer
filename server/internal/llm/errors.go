package llm

import "fmt"

// ConnectionError indicates the LLM provider could not be reached.
type ConnectionError struct {
	Err error
}

func (e *ConnectionError) Error() string {
	return fmt.Sprintf("LLM connection error: %v", e.Err)
}

func (e *ConnectionError) Unwrap() error {
	return e.Err
}

// TimeoutError indicates the LLM request timed out.
type TimeoutError struct {
	Err error
}

func (e *TimeoutError) Error() string {
	return fmt.Sprintf("LLM request timeout: %v", e.Err)
}

func (e *TimeoutError) Unwrap() error {
	return e.Err
}
