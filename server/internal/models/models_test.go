package models

import (
	"encoding/json"
	"testing"
	"time"
)

// roundTrip marshals v to JSON and unmarshals into dst, failing on error.
func roundTrip(t *testing.T, v any, dst any) {
	t.Helper()
	data, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("json.Marshal error: %v", err)
	}
	if err := json.Unmarshal(data, dst); err != nil {
		t.Fatalf("json.Unmarshal error: %v", err)
	}
}

func TestEmailRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	recCount := 3
	original := Email{
		ID:         "550e8400-e29b-41d4-a716-446655440000",
		AccountID:  "660e8400-e29b-41d4-a716-446655440001",
		MessageID:  "<abc@example.com>",
		From:       Contact{Name: "Jane", Email: "jane@example.com"},
		To:         []Contact{{Email: "bob@example.com"}},
		Subject:    "Test Subject",
		Snippet:    "First 200 chars...",
		ReceivedAt: now,
		Classification: &Classification{
			Classification: ClassActionRequired,
			Confidence:     0.95,
			ClassifiedBy:   ClassifiedByRules,
		},
		IsRead:              true,
		HasAttachments:      true,
		Labels:              []string{"important"},
		AccountColor:        "#3B82F6",
		AccountName:         "Work",
		RecommendationCount: &recCount,
	}

	var decoded Email
	roundTrip(t, original, &decoded)

	if decoded.ID != original.ID {
		t.Errorf("ID: got %s, want %s", decoded.ID, original.ID)
	}
	if decoded.From.Name != "Jane" {
		t.Errorf("From.Name: got %s, want Jane", decoded.From.Name)
	}
	if decoded.Classification.Classification != ClassActionRequired {
		t.Errorf("Classification: got %s, want %s", decoded.Classification.Classification, ClassActionRequired)
	}
	if decoded.RecommendationCount == nil || *decoded.RecommendationCount != 3 {
		t.Error("RecommendationCount not preserved")
	}
	if !decoded.ReceivedAt.Equal(now) {
		t.Errorf("ReceivedAt: got %v, want %v", decoded.ReceivedAt, now)
	}
}

func TestEmailDetailRoundTrip(t *testing.T) {
	original := EmailDetail{
		ID: "test-id",
		Email: Email{
			ID:      "test-id",
			Subject: "Detail Test",
			From:    Contact{Email: "a@b.com"},
			To:      []Contact{{Email: "c@d.com"}},
		},
		HTMLBody: "<p>Hello</p>",
		TextBody: "Hello",
		Attachments: []Attachment{
			{ID: "att-1", Filename: "doc.pdf", MIMEType: "application/pdf", Size: 1024},
		},
	}

	var decoded EmailDetail
	roundTrip(t, original, &decoded)

	if decoded.HTMLBody != "<p>Hello</p>" {
		t.Errorf("HTMLBody: got %s", decoded.HTMLBody)
	}
	if len(decoded.Attachments) != 1 || decoded.Attachments[0].Filename != "doc.pdf" {
		t.Error("Attachments not preserved")
	}
}

func TestClassificationRoundTrip(t *testing.T) {
	original := Classification{
		Classification: ClassNewsletter,
		Confidence:     0.87,
		ClassifiedBy:   ClassifiedByLLM,
		Reason:         "Newsletter pattern detected",
		IsOverridden:   true,
	}

	var decoded Classification
	roundTrip(t, original, &decoded)

	if decoded.Classification != ClassNewsletter {
		t.Errorf("Classification: got %s, want %s", decoded.Classification, ClassNewsletter)
	}
	if decoded.IsOverridden != true {
		t.Error("IsOverridden not preserved")
	}
}

func TestSnoozeStateRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	returnAt := now.Add(24 * time.Hour)
	original := SnoozeState{
		ID:          "snooze-1",
		EmailID:     "email-1",
		SnoozedAt:   now,
		ReturnAt:    returnAt,
		SnoozeCount: 2,
		IsActive:    true,
	}

	var decoded SnoozeState
	roundTrip(t, original, &decoded)

	if decoded.SnoozeCount != 2 {
		t.Errorf("SnoozeCount: got %d, want 2", decoded.SnoozeCount)
	}
	if !decoded.ReturnAt.Equal(returnAt) {
		t.Errorf("ReturnAt: got %v, want %v", decoded.ReturnAt, returnAt)
	}
}

func TestRecommendationRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := Recommendation{
		ID:                   "rec-1",
		Type:                 RecTypeBook,
		Title:                "The Innovator's Dilemma",
		Creator:              "Clayton Christensen",
		SourceNewsletterName: "Stratechery",
		SourceDate:           now,
		ContextSnippet:       "Ben called it the best...",
		Status:               RecStatusSaved,
		DuplicateCount:       3,
		IsUserAdded:          false,
		CreatedAt:            now,
	}

	var decoded Recommendation
	roundTrip(t, original, &decoded)

	if decoded.Type != RecTypeBook {
		t.Errorf("Type: got %s, want %s", decoded.Type, RecTypeBook)
	}
	if decoded.Status != RecStatusSaved {
		t.Errorf("Status: got %s, want %s", decoded.Status, RecStatusSaved)
	}
	if decoded.DuplicateCount != 3 {
		t.Errorf("DuplicateCount: got %d, want 3", decoded.DuplicateCount)
	}
}

func TestRecommendationDetailRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := RecommendationDetail{
		Recommendation: Recommendation{
			ID:    "rec-1",
			Type:  RecTypeMovie,
			Title: "Inception",
		},
		FullContext: "A long paragraph about Inception...",
		DuplicateSources: []DuplicateSource{
			{NewsletterName: "Film Weekly", Date: now, ContextSnippet: "snippet"},
		},
	}

	var decoded RecommendationDetail
	roundTrip(t, original, &decoded)

	if decoded.FullContext != original.FullContext {
		t.Errorf("FullContext not preserved")
	}
	if len(decoded.DuplicateSources) != 1 {
		t.Error("DuplicateSources not preserved")
	}
}

func TestDailyDigestRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	count := 5
	original := DailyDigest{
		ID:          "digest-1",
		DigestType:  DigestTypeMorning,
		GeneratedAt: now,
		IsRead:      false,
		Sections: []DigestSection{
			{
				Type:  "action_queue_summary",
				Title: "ACTION QUEUE",
				Count: &count,
				AccountBreakdown: []AccountCount{
					{AccountID: "acc-1", AccountName: "Work", AccountColor: "#3B82F6", Count: 3},
				},
			},
		},
	}

	var decoded DailyDigest
	roundTrip(t, original, &decoded)

	if decoded.DigestType != DigestTypeMorning {
		t.Errorf("DigestType: got %s, want %s", decoded.DigestType, DigestTypeMorning)
	}
	if len(decoded.Sections) != 1 {
		t.Fatal("Sections not preserved")
	}
	if decoded.Sections[0].Count == nil || *decoded.Sections[0].Count != 5 {
		t.Error("Section Count not preserved")
	}
}

func TestDigestSummaryRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := DigestSummary{
		ID:          "digest-1",
		DigestType:  DigestTypeEvening,
		GeneratedAt: now,
		IsRead:      true,
	}

	var decoded DigestSummary
	roundTrip(t, original, &decoded)

	if decoded.DigestType != DigestTypeEvening {
		t.Errorf("DigestType: got %s, want %s", decoded.DigestType, DigestTypeEvening)
	}
}

func TestAccountRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := Account{
		ID:           "acc-1",
		Name:         "Work",
		EmailAddress: "me@work.com",
		AccountType:  AccountTypeWork,
		Color:        "#3B82F6",
		Status:       AccountStatusOnline,
		Counts: &AccountCounts{
			ActionQueue:  5,
			ReadingQueue: 12,
			Filtered:     30,
		},
		CreatedAt: now,
		UpdatedAt: now,
	}

	var decoded Account
	roundTrip(t, original, &decoded)

	if decoded.AccountType != AccountTypeWork {
		t.Errorf("AccountType: got %s, want %s", decoded.AccountType, AccountTypeWork)
	}
	if decoded.Counts == nil || decoded.Counts.ActionQueue != 5 {
		t.Error("Counts not preserved")
	}
}

func TestVIPSenderRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := VIPSender{
		ID:      "vip-1",
		Email:   "boss@company.com",
		Name:    "My Boss",
		AddedAt: now,
	}

	var decoded VIPSender
	roundTrip(t, original, &decoded)

	if decoded.Email != "boss@company.com" {
		t.Errorf("Email: got %s", decoded.Email)
	}
}

func TestHealthResponseRoundTrip(t *testing.T) {
	original := HealthResponse{
		Status:        HealthStatusHealthy,
		Version:       "1.0.0",
		Commit:        "abc1234",
		UptimeSeconds: 3600,
		Checks: &HealthChecks{
			Database: CheckStatusOK,
			Ollama:   CheckStatusUnavailable,
			IMAP:     map[string]string{"work": "connected"},
		},
	}

	var decoded HealthResponse
	roundTrip(t, original, &decoded)

	if decoded.Status != HealthStatusHealthy {
		t.Errorf("Status: got %s", decoded.Status)
	}
	if decoded.Checks.IMAP["work"] != "connected" {
		t.Error("IMAP check not preserved")
	}
}

func TestWebSocketEventRoundTrip(t *testing.T) {
	payload, _ := json.Marshal(map[string]string{"email_id": "e-1"})
	original := WebSocketEvent{
		Type:    WSEventEmailNew,
		Payload: payload,
	}

	var decoded WebSocketEvent
	roundTrip(t, original, &decoded)

	if decoded.Type != WSEventEmailNew {
		t.Errorf("Type: got %s, want %s", decoded.Type, WSEventEmailNew)
	}

	var p map[string]string
	if err := json.Unmarshal(decoded.Payload, &p); err != nil {
		t.Fatalf("Payload unmarshal error: %v", err)
	}
	if p["email_id"] != "e-1" {
		t.Error("Payload email_id not preserved")
	}
}

func TestComposeRequestRoundTrip(t *testing.T) {
	original := ComposeRequest{
		AccountID: "acc-1",
		To:        []string{"bob@example.com"},
		CC:        []string{"cc@example.com"},
		Subject:   "Hello",
		Body:      "Hi there",
		InReplyTo: "reply-to-id",
	}

	var decoded ComposeRequest
	roundTrip(t, original, &decoded)

	if len(decoded.To) != 1 || decoded.To[0] != "bob@example.com" {
		t.Error("To not preserved")
	}
	if decoded.InReplyTo != "reply-to-id" {
		t.Errorf("InReplyTo: got %s", decoded.InReplyTo)
	}
}

func TestDraftRoundTrip(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	original := Draft{
		ID:        "draft-1",
		AccountID: "acc-1",
		To:        []string{"a@b.com"},
		Subject:   "Draft subject",
		Body:      "Draft body",
		CreatedAt: now,
		UpdatedAt: now,
	}

	var decoded Draft
	roundTrip(t, original, &decoded)

	if decoded.Subject != "Draft subject" {
		t.Errorf("Subject: got %s", decoded.Subject)
	}
}

func TestSearchResultRoundTrip(t *testing.T) {
	original := SearchResult{
		Email: Email{
			ID:      "e-1",
			Subject: "Found it",
			From:    Contact{Email: "a@b.com"},
			To:      []Contact{{Email: "c@d.com"}},
		},
		HighlightSnippet: "...the <mark>search term</mark>...",
	}

	var decoded SearchResult
	roundTrip(t, original, &decoded)

	if decoded.HighlightSnippet != original.HighlightSnippet {
		t.Errorf("HighlightSnippet: got %s", decoded.HighlightSnippet)
	}
}

func TestSearchResponseRoundTrip(t *testing.T) {
	original := SearchResponse{
		Data:    []SearchResult{},
		HasMore: false,
		Query:   "test query",
	}

	var decoded SearchResponse
	roundTrip(t, original, &decoded)

	if decoded.Query != "test query" {
		t.Errorf("Query: got %s", decoded.Query)
	}
}
