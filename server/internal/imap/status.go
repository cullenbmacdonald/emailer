package imap

import (
	"github.com/cullenbmacdonald/emailer/internal/models"
)

// StatusMonitor tracks IMAP account statuses and provides health check data.
type StatusMonitor struct {
	manager *Manager
}

// NewStatusMonitor creates a status monitor for the given IMAP manager.
func NewStatusMonitor(manager *Manager) *StatusMonitor {
	return &StatusMonitor{manager: manager}
}

// AccountStatusMap returns a map of account ID to status string.
func (sm *StatusMonitor) AccountStatusMap() map[string]string {
	statuses := sm.manager.AccountStatuses()
	result := make(map[string]string, len(statuses))
	for id, acct := range statuses {
		result[id] = acct.Status
	}
	return result
}

// OverallStatus returns the aggregate IMAP health status:
// - "ok" if all accounts are online
// - models.HealthStatusDegraded if some accounts are offline/error
// - "error" if all accounts are offline/error
// - "ok" if no accounts are configured
func (sm *StatusMonitor) OverallStatus() string {
	if sm.manager.AccountCount() == 0 {
		return models.CheckStatusOK
	}

	statuses := sm.manager.AccountStatuses()
	onlineCount := 0
	for _, acct := range statuses {
		if acct.Status == models.AccountStatusOnline || acct.Status == models.AccountStatusSyncing {
			onlineCount++
		}
	}

	if onlineCount == len(statuses) {
		return models.CheckStatusOK
	}
	if onlineCount == 0 {
		return models.CheckStatusError
	}
	return models.HealthStatusDegraded
}

// HealthStatus returns the overall health status string for the health endpoint,
// considering IMAP status alongside other checks.
func (sm *StatusMonitor) HealthStatus(dbOK bool) string {
	if !dbOK {
		return models.HealthStatusUnhealthy
	}

	imapStatus := sm.OverallStatus()
	switch imapStatus {
	case models.CheckStatusError:
		return models.HealthStatusUnhealthy
	case models.HealthStatusDegraded:
		return models.HealthStatusDegraded
	default:
		return models.HealthStatusHealthy
	}
}
