package models

import (
	"encoding/base64"
	"fmt"
	"strings"
)

// Default and maximum page sizes.
const (
	DefaultPageSize = 50
	MaxPageSize     = 100
)

// EncodeCursor encodes composite key parts into an opaque cursor string.
// Parts are joined with "|" and base64-encoded.
func EncodeCursor(parts ...string) string {
	joined := strings.Join(parts, "|")
	return base64.URLEncoding.EncodeToString([]byte(joined))
}

// DecodeCursor decodes an opaque cursor string into its composite key parts.
func DecodeCursor(cursor string) ([]string, error) {
	data, err := base64.URLEncoding.DecodeString(cursor)
	if err != nil {
		return nil, fmt.Errorf("invalid cursor: %w", err)
	}
	parts := strings.Split(string(data), "|")
	if len(parts) == 0 {
		return nil, fmt.Errorf("invalid cursor: empty")
	}
	return parts, nil
}

// ClampPageSize ensures the limit is within valid bounds.
func ClampPageSize(limit int) int {
	if limit <= 0 {
		return DefaultPageSize
	}
	if limit > MaxPageSize {
		return MaxPageSize
	}
	return limit
}
