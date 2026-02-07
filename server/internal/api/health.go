package api

import (
	"net/http"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// handleHealth returns the health check handler.
func (s *Server) handleHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		uptime := int(time.Since(s.startTime).Seconds())

		dbStatus := models.CheckStatusError
		if s.pool != nil {
			if err := s.pool.Ping(ctx); err == nil {
				dbStatus = models.CheckStatusOK
			}
		}

		status := models.HealthStatusHealthy
		statusCode := http.StatusOK
		if dbStatus == models.CheckStatusError {
			status = models.HealthStatusUnhealthy
			statusCode = http.StatusServiceUnavailable
		}

		resp := models.HealthResponse{
			Status:        status,
			Version:       s.buildInfo.Version,
			Commit:        s.buildInfo.Commit,
			UptimeSeconds: uptime,
			Checks: &models.HealthChecks{
				Database: dbStatus,
			},
		}

		WriteJSON(w, statusCode, resp)
	}
}
