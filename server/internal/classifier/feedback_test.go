package classifier

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

type mockTrainingStore struct {
	signals []trainingSignal
	counts  map[string]int // "sender:class" -> count
	err     error
}

type trainingSignal struct {
	emailID, prev, new string
	isConfirm          bool
}

func (m *mockTrainingStore) RecordTrainingSignal(_ context.Context, emailID, prev, newClass string, isConfirm bool) error {
	if m.err != nil {
		return m.err
	}
	m.signals = append(m.signals, trainingSignal{emailID, prev, newClass, isConfirm})
	return nil
}

func (m *mockTrainingStore) CountOverridesForSender(_ context.Context, senderEmail, classification string) (int, error) {
	if m.err != nil {
		return 0, m.err
	}
	key := senderEmail + ":" + classification
	return m.counts[key], nil
}

type mockSenderStatsUpdater struct {
	increments     []statsUpdate
	mostCommonSets []statsUpdate
	err            error
}

type statsUpdate struct {
	senderEmail, class string
}

func (m *mockSenderStatsUpdater) IncrementClassCount(_ context.Context, senderEmail, class string) error {
	if m.err != nil {
		return m.err
	}
	m.increments = append(m.increments, statsUpdate{senderEmail, class})
	return nil
}

func (m *mockSenderStatsUpdater) SetMostCommonClass(_ context.Context, senderEmail, class string) error {
	if m.err != nil {
		return m.err
	}
	m.mostCommonSets = append(m.mostCommonSets, statsUpdate{senderEmail, class})
	return nil
}

type mockEmailLookup struct {
	senders map[string]string // emailID -> senderEmail
	err     error
}

func (m *mockEmailLookup) GetSenderEmail(_ context.Context, emailID string) (string, error) {
	if m.err != nil {
		return "", m.err
	}
	return m.senders[emailID], nil
}

func TestFeedbackProcessor_RecordsTrainingSignal(t *testing.T) {
	training := &mockTrainingStore{counts: map[string]int{}}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{senders: map[string]string{"e1": "sender@test.com"}}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	err := fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)
	if err != nil {
		t.Fatal(err)
	}

	if len(training.signals) != 1 {
		t.Fatalf("expected 1 signal, got %d", len(training.signals))
	}
	s := training.signals[0]
	if s.emailID != "e1" || s.prev != models.ClassFiltered || s.new != models.ClassNewsletter || s.isConfirm {
		t.Errorf("unexpected signal: %+v", s)
	}
}

func TestFeedbackProcessor_UpdatesSenderStats(t *testing.T) {
	training := &mockTrainingStore{counts: map[string]int{}}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{senders: map[string]string{"e1": "sender@test.com"}}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	err := fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)
	if err != nil {
		t.Fatal(err)
	}

	if len(stats.increments) != 1 {
		t.Fatalf("expected 1 increment, got %d", len(stats.increments))
	}
	if stats.increments[0].senderEmail != "sender@test.com" || stats.increments[0].class != models.ClassNewsletter {
		t.Errorf("unexpected increment: %+v", stats.increments[0])
	}
}

func TestFeedbackProcessor_SetsMostCommonClassAfter3Overrides(t *testing.T) {
	training := &mockTrainingStore{
		counts: map[string]int{
			"sender@test.com:" + models.ClassNewsletter: 3,
		},
	}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{senders: map[string]string{"e1": "sender@test.com"}}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	err := fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)
	if err != nil {
		t.Fatal(err)
	}

	if len(stats.mostCommonSets) != 1 {
		t.Fatalf("expected most_common_class to be set, got %d", len(stats.mostCommonSets))
	}
	if stats.mostCommonSets[0].class != models.ClassNewsletter {
		t.Errorf("expected newsletter, got %s", stats.mostCommonSets[0].class)
	}
}

func TestFeedbackProcessor_DoesNotSetMostCommonClassBelow3(t *testing.T) {
	training := &mockTrainingStore{
		counts: map[string]int{
			"sender@test.com:" + models.ClassNewsletter: 2,
		},
	}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{senders: map[string]string{"e1": "sender@test.com"}}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	_ = fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)

	if len(stats.mostCommonSets) != 0 {
		t.Error("should not set most_common_class with only 2 overrides")
	}
}

func TestFeedbackProcessor_ConfirmStrengthensExisting(t *testing.T) {
	training := &mockTrainingStore{counts: map[string]int{}}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{senders: map[string]string{"e1": "sender@test.com"}}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	err := fp.ProcessOverride(context.Background(), "e1", models.ClassActionRequired, models.ClassActionRequired, true)
	if err != nil {
		t.Fatal(err)
	}

	if len(training.signals) != 1 || !training.signals[0].isConfirm {
		t.Error("confirm signal not recorded properly")
	}
	if len(stats.increments) != 1 || stats.increments[0].class != models.ClassActionRequired {
		t.Error("confirm should increment stats for the confirmed class")
	}
}

func TestFeedbackProcessor_TrainingPeriod(t *testing.T) {
	// During training period (first 2 weeks)
	fp := NewFeedbackProcessor(nil, nil, nil, time.Now(), testLogger())
	if !fp.IsTrainingPeriod() {
		t.Error("should be in training period")
	}
	if fp.BorderlineThreshold() != 0.85 {
		t.Errorf("expected 0.85 during training, got %f", fp.BorderlineThreshold())
	}

	// After training period
	fp2 := NewFeedbackProcessor(nil, nil, nil, time.Now().Add(-15*24*time.Hour), testLogger())
	if fp2.IsTrainingPeriod() {
		t.Error("should not be in training period")
	}
	if fp2.BorderlineThreshold() != 0.80 {
		t.Errorf("expected 0.80 after training, got %f", fp2.BorderlineThreshold())
	}
}

func TestFeedbackProcessor_LookupError(t *testing.T) {
	training := &mockTrainingStore{counts: map[string]int{}}
	stats := &mockSenderStatsUpdater{}
	lookup := &mockEmailLookup{err: errors.New("not found")}

	fp := NewFeedbackProcessor(training, stats, lookup, time.Now(), testLogger())

	// Should not return error, just log warning
	err := fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)
	if err != nil {
		t.Fatal(err)
	}

	// Training signal should still be recorded
	if len(training.signals) != 1 {
		t.Error("training signal should be recorded even if lookup fails")
	}
	// But stats should not be updated
	if len(stats.increments) != 0 {
		t.Error("stats should not be updated when lookup fails")
	}
}

func TestFeedbackProcessor_NilDependencies(t *testing.T) {
	fp := NewFeedbackProcessor(nil, nil, nil, time.Now(), testLogger())

	// Should not panic with nil dependencies
	err := fp.ProcessOverride(context.Background(), "e1", models.ClassFiltered, models.ClassNewsletter, false)
	if err != nil {
		t.Fatal(err)
	}
}
