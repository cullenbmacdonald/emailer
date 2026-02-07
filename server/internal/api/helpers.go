package api

import (
	"encoding/json"
	"net/http"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/rs/zerolog/log"
)

const contentTypeJSON = "application/json"

// WriteJSON writes a JSON response with the given status code.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", contentTypeJSON)
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Error().Err(err).Msg("failed to encode JSON response")
	}
}

// WriteError writes a standard API error response.
func WriteError(w http.ResponseWriter, status int, code, message string) {
	WriteJSON(w, status, models.APIError{
		Code:    code,
		Message: message,
	})
}
