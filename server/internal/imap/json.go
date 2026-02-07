package imap

import "encoding/json"

// jsonMarshal is a package-level helper to avoid repeated json.Marshal imports.
func jsonMarshal(v any) ([]byte, error) {
	return json.Marshal(v)
}
