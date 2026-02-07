package models

// HealthResponse is the response from the health check endpoint.
type HealthResponse struct {
	Status        string        `json:"status"`
	Version       string        `json:"version,omitempty"`
	Commit        string        `json:"commit,omitempty"`
	UptimeSeconds int           `json:"uptime_seconds"`
	Checks        *HealthChecks `json:"checks,omitempty"`
}

// HealthChecks holds the status of external dependencies.
type HealthChecks struct {
	Database string            `json:"database"`
	Ollama   string            `json:"ollama,omitempty"`
	IMAP     map[string]string `json:"imap,omitempty"`
}

// Health status values.
const (
	HealthStatusHealthy   = "healthy"
	HealthStatusDegraded  = "degraded"
	HealthStatusUnhealthy = "unhealthy"
)

// Check status values.
const (
	CheckStatusOK          = "ok"
	CheckStatusError       = "error"
	CheckStatusUnavailable = "unavailable"
)
