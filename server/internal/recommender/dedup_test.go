package recommender

import "testing"

func TestNormalizeTitle(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"The Great Gatsby", "great gatsby"},
		{"A Brief History of Time", "brief history of time"},
		{"An Introduction to Go", "introduction to go"},
		{"  hello   world  ", "hello world"},
		{"UPPER CASE", "upper case"},
		{"", ""},
		{"The", "the"},
		{"A", "a"},
		{"normal title", "normal title"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := NormalizeTitle(tt.input)
			if got != tt.want {
				t.Errorf("NormalizeTitle(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestTitlesMatch(t *testing.T) {
	tests := []struct {
		a, b string
		want bool
	}{
		{"The Great Gatsby", "the great gatsby", true},
		{"The Great Gatsby", "Great Gatsby", true},
		{"  Hello World  ", "hello   world", true},
		{"A Book", "Book", true},
		{"Different Book", "Another Book", false},
		{"", "", true},
		{"Something", "Something Else", false},
	}

	for _, tt := range tests {
		t.Run(tt.a+"_vs_"+tt.b, func(t *testing.T) {
			got := TitlesMatch(tt.a, tt.b)
			if got != tt.want {
				t.Errorf("TitlesMatch(%q, %q) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}
