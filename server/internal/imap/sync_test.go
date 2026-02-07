package imap

import (
	"testing"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestMarshalContacts_Nil(t *testing.T) {
	b, err := marshalContacts(nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(b) != "[]" {
		t.Errorf("expected empty JSON array, got %s", string(b))
	}
}

func TestMarshalContacts_NonEmpty(t *testing.T) {
	contacts := []models.Contact{
		{Name: "Alice", Email: "alice@example.com"},
	}
	b, err := marshalContacts(contacts)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	s := string(b)
	if s == "" || s == "[]" {
		t.Errorf("expected non-empty JSON, got %s", s)
	}
}

func TestMarshalLabels_Nil(t *testing.T) {
	b, err := marshalLabels(nil)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(b) != "[]" {
		t.Errorf("expected empty JSON array, got %s", string(b))
	}
}

func TestMarshalLabels_NonEmpty(t *testing.T) {
	labels := []string{"inbox", "important"}
	b, err := marshalLabels(labels)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	s := string(b)
	if s == "" || s == "[]" {
		t.Errorf("expected non-empty JSON, got %s", s)
	}
}

func TestNewEmailSyncer(t *testing.T) {
	// Verify constructor doesn't panic with nil pool (used for testing).
	syncer := NewEmailSyncer(nil, zerolog.Nop())
	if syncer == nil {
		t.Fatal("expected non-nil syncer")
	}
}
