package classifier

import (
	"context"
	"io"

	"github.com/rs/zerolog"
)

func testLogger() zerolog.Logger {
	return zerolog.New(io.Discard)
}

// mockVIPChecker implements VIPChecker for testing.
type mockVIPChecker struct {
	vips map[string]bool
	err  error
}

func (m *mockVIPChecker) IsVIP(_ context.Context, email string) (bool, error) {
	if m.err != nil {
		return false, m.err
	}
	return m.vips[email], nil
}

// mockSenderStats implements SenderStatsProvider for testing.
type mockSenderStats struct {
	replyRates map[string]float64
	priorClass map[string]string
}

func (m *mockSenderStats) GetReplyRate(_ context.Context, email string) (float64, bool, error) {
	rate, ok := m.replyRates[email]
	return rate, ok, nil
}

func (m *mockSenderStats) GetPriorClass(_ context.Context, email string) (string, bool, error) {
	class, ok := m.priorClass[email]
	return class, ok, nil
}

// mockLLMClassifier implements LLMClassifier for testing.
type mockLLMClassifier struct {
	result *ClassificationResult
	err    error
}

func (m *mockLLMClassifier) Classify(_ context.Context, _ *EmailInput) (*ClassificationResult, error) {
	return m.result, m.err
}
