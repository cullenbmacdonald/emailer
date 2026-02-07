package imap

import (
	"testing"
	"time"

	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/rs/zerolog"
)

func TestConvertAddress_Single(t *testing.T) {
	addrs := []imap.Address{
		{Name: "John Doe", Mailbox: "john", Host: "example.com"},
	}
	contact := convertAddress(addrs)
	if contact.Name != "John Doe" {
		t.Errorf("expected name 'John Doe', got %q", contact.Name)
	}
	if contact.Email != "john@example.com" {
		t.Errorf("expected email 'john@example.com', got %q", contact.Email)
	}
}

func TestConvertAddress_Empty(t *testing.T) {
	contact := convertAddress(nil)
	if contact.Email != "" || contact.Name != "" {
		t.Errorf("expected empty contact, got %+v", contact)
	}
}

func TestConvertAddresses_Multiple(t *testing.T) {
	addrs := []imap.Address{
		{Name: "Alice", Mailbox: "alice", Host: "example.com"},
		{Name: "Bob", Mailbox: "bob", Host: "example.com"},
	}
	contacts := convertAddresses(addrs)
	if len(contacts) != 2 {
		t.Fatalf("expected 2 contacts, got %d", len(contacts))
	}
	if contacts[0].Email != "alice@example.com" {
		t.Errorf("expected alice@example.com, got %s", contacts[0].Email)
	}
	if contacts[1].Email != "bob@example.com" {
		t.Errorf("expected bob@example.com, got %s", contacts[1].Email)
	}
}

func TestConvertAddresses_SkipsGroupMarkers(t *testing.T) {
	addrs := []imap.Address{
		{Name: "Group", Mailbox: "group-name", Host: ""}, // Group start marker.
		{Name: "Alice", Mailbox: "alice", Host: "example.com"},
		{Mailbox: "", Host: ""}, // Group end marker.
	}
	contacts := convertAddresses(addrs)
	if len(contacts) != 1 {
		t.Fatalf("expected 1 contact (group markers skipped), got %d", len(contacts))
	}
	if contacts[0].Email != "alice@example.com" {
		t.Errorf("expected alice@example.com, got %s", contacts[0].Email)
	}
}

func TestConvertAddresses_Empty(t *testing.T) {
	contacts := convertAddresses(nil)
	if contacts != nil {
		t.Errorf("expected nil, got %v", contacts)
	}
}

func TestResolveDate_PrefersEnvelope(t *testing.T) {
	envDate := time.Date(2024, 1, 15, 10, 0, 0, 0, time.UTC)
	internalDate := time.Date(2024, 1, 16, 10, 0, 0, 0, time.UTC)

	got := resolveDate(envDate, internalDate)
	if !got.Equal(envDate) {
		t.Errorf("expected envelope date, got %v", got)
	}
}

func TestResolveDate_FallsBackToInternal(t *testing.T) {
	internalDate := time.Date(2024, 1, 16, 10, 0, 0, 0, time.UTC)

	got := resolveDate(time.Time{}, internalDate)
	if !got.Equal(internalDate) {
		t.Errorf("expected internal date, got %v", got)
	}
}

func TestHasFlag(t *testing.T) {
	flags := []imap.Flag{imap.FlagSeen, imap.FlagFlagged}

	if !hasFlag(flags, imap.FlagSeen) {
		t.Error("expected to find \\Seen flag")
	}
	if !hasFlag(flags, imap.FlagFlagged) {
		t.Error("expected to find \\Flagged flag")
	}
	if hasFlag(flags, imap.FlagDeleted) {
		t.Error("expected not to find \\Deleted flag")
	}
	if hasFlag(nil, imap.FlagSeen) {
		t.Error("expected empty flags to not match")
	}
}

func TestBuildUIDSet(t *testing.T) {
	uids := []imap.UID{1, 5, 10}
	set := buildUIDSet(uids)

	// UIDSet should contain all three UIDs.
	if !set.Contains(1) {
		t.Error("expected set to contain UID 1")
	}
	if !set.Contains(5) {
		t.Error("expected set to contain UID 5")
	}
	if !set.Contains(10) {
		t.Error("expected set to contain UID 10")
	}
}

func TestBuildPartialResult(t *testing.T) {
	buf := &imapclient.FetchMessageBuffer{
		UID:          42,
		Flags:        []imap.Flag{imap.FlagSeen},
		InternalDate: time.Date(2024, 1, 15, 10, 0, 0, 0, time.UTC),
		Envelope: &imap.Envelope{
			Subject: "Test Subject",
			From: []imap.Address{
				{Name: "Sender", Mailbox: "sender", Host: "example.com"},
			},
			To: []imap.Address{
				{Name: "Recipient", Mailbox: "recipient", Host: "example.com"},
			},
			MessageID: "test-msg-id",
		},
	}

	cfg := AccountFetchConfig{
		AccountID:    "acct-1",
		AccountName:  "Test Account",
		AccountColor: "#FF0000",
	}

	result := buildPartialResult(buf, cfg)

	if result.UID != 42 {
		t.Errorf("expected UID 42, got %d", result.UID)
	}
	if result.MessageID != "test-msg-id" {
		t.Errorf("expected message ID test-msg-id, got %s", result.MessageID)
	}
	if result.Email.Subject != "Test Subject" {
		t.Errorf("expected subject 'Test Subject', got %s", result.Email.Subject)
	}
	if result.Email.From.Email != "sender@example.com" {
		t.Errorf("expected from email sender@example.com, got %s", result.Email.From.Email)
	}
	if !result.Email.IsRead {
		t.Error("expected IsRead=true (message has \\Seen flag)")
	}
	if result.Email.AccountID != "acct-1" {
		t.Errorf("expected account ID acct-1, got %s", result.Email.AccountID)
	}
}

func TestBuildPartialResult_NoEnvelope(t *testing.T) {
	buf := &imapclient.FetchMessageBuffer{
		UID:          99,
		InternalDate: time.Date(2024, 1, 15, 10, 0, 0, 0, time.UTC),
	}

	cfg := AccountFetchConfig{AccountID: "acct-1"}
	result := buildPartialResult(buf, cfg)

	if result.Email.Subject != "" {
		t.Errorf("expected empty subject, got %s", result.Email.Subject)
	}
	if result.MessageID != "" {
		t.Errorf("expected empty message ID, got %s", result.MessageID)
	}
}

func TestProcessFetchedMessage_WithEnvelopeAndBody(t *testing.T) {
	textBody := "Hello, this is a test email body."
	rawEmail := "From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test\r\nContent-Type: text/plain\r\n\r\n" + textBody

	buf := &imapclient.FetchMessageBuffer{
		UID:          10,
		Flags:        []imap.Flag{},
		InternalDate: time.Date(2024, 1, 15, 10, 0, 0, 0, time.UTC),
		Envelope: &imap.Envelope{
			Subject:   "Test Email",
			Date:      time.Date(2024, 1, 15, 9, 30, 0, 0, time.UTC),
			From:      []imap.Address{{Name: "Sender", Mailbox: "sender", Host: "example.com"}},
			To:        []imap.Address{{Name: "Recipient", Mailbox: "recipient", Host: "example.com"}},
			Cc:        []imap.Address{{Name: "CC Person", Mailbox: "cc", Host: "example.com"}},
			MessageID: "test-process-001",
			InReplyTo: []string{"original-thread-001"},
		},
		BodySection: []imapclient.FetchBodySectionBuffer{
			{Bytes: []byte(rawEmail)},
		},
	}

	cfg := AccountFetchConfig{
		AccountID:    "acct-1",
		AccountName:  "Test",
		AccountColor: "#00FF00",
	}

	result, err := processFetchedMessage(buf, cfg, zerolog.Nop())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.UID != 10 {
		t.Errorf("expected UID 10, got %d", result.UID)
	}
	if result.MessageID != "test-process-001" {
		t.Errorf("expected message ID, got %s", result.MessageID)
	}
	if result.ThreadID != "original-thread-001" {
		t.Errorf("expected thread ID from In-Reply-To, got %s", result.ThreadID)
	}
	if result.Email.Subject != "Test Email" {
		t.Errorf("expected subject 'Test Email', got %s", result.Email.Subject)
	}
	if result.Email.From.Email != "sender@example.com" {
		t.Errorf("expected from email, got %s", result.Email.From.Email)
	}
	if len(result.Email.To) != 1 || result.Email.To[0].Email != "recipient@example.com" {
		t.Errorf("unexpected To contacts: %+v", result.Email.To)
	}
	if len(result.Email.CC) != 1 || result.Email.CC[0].Email != "cc@example.com" {
		t.Errorf("unexpected CC contacts: %+v", result.Email.CC)
	}
	if result.Email.IsRead {
		t.Error("expected IsRead=false (no \\Seen flag)")
	}
	if result.TextBody == "" {
		t.Error("expected non-empty text body")
	}
	if result.Email.Snippet == "" {
		t.Error("expected non-empty snippet")
	}
}

func TestProcessFetchedMessage_NoEnvelope(t *testing.T) {
	buf := &imapclient.FetchMessageBuffer{
		UID: 10,
	}
	cfg := AccountFetchConfig{AccountID: "acct-1"}

	_, err := processFetchedMessage(buf, cfg, zerolog.Nop())
	if err == nil {
		t.Fatal("expected error for missing envelope")
	}
}
