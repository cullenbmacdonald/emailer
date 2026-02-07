package models

import "testing"

func TestEncodeDecode(t *testing.T) {
	parts := []string{"2026-02-07T14:30:00Z", "550e8400-e29b-41d4-a716-446655440000"}
	cursor := EncodeCursor(parts...)

	decoded, err := DecodeCursor(cursor)
	if err != nil {
		t.Fatalf("DecodeCursor error: %v", err)
	}

	if len(decoded) != len(parts) {
		t.Fatalf("expected %d parts, got %d", len(parts), len(decoded))
	}
	for i, want := range parts {
		if decoded[i] != want {
			t.Errorf("parts[%d]: got %s, want %s", i, decoded[i], want)
		}
	}
}

func TestDecodeCursorInvalid(t *testing.T) {
	_, err := DecodeCursor("not-valid-base64!!!")
	if err == nil {
		t.Error("expected error for invalid cursor, got nil")
	}
}

func TestEncodeCursorSinglePart(t *testing.T) {
	cursor := EncodeCursor("single-value")
	parts, err := DecodeCursor(cursor)
	if err != nil {
		t.Fatalf("DecodeCursor error: %v", err)
	}
	if len(parts) != 1 || parts[0] != "single-value" {
		t.Errorf("expected [single-value], got %v", parts)
	}
}

func TestClampPageSize(t *testing.T) {
	tests := []struct {
		input    int
		expected int
	}{
		{0, DefaultPageSize},
		{-1, DefaultPageSize},
		{1, 1},
		{50, 50},
		{100, 100},
		{101, MaxPageSize},
		{999, MaxPageSize},
	}

	for _, tt := range tests {
		got := ClampPageSize(tt.input)
		if got != tt.expected {
			t.Errorf("ClampPageSize(%d) = %d, want %d", tt.input, got, tt.expected)
		}
	}
}
