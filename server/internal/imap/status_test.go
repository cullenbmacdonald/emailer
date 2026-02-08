package imap

import (
	"testing"

	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

func TestStatusMonitor_AllOnline(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	// Set all accounts to online
	for _, id := range []string{"gmail-1", "icloud-1", "ms-1"} {
		acct, _ := mgr.Account(id)
		acct.setStatus(models.AccountStatusOnline, "")
	}

	sm := NewStatusMonitor(mgr)

	statusMap := sm.AccountStatusMap()
	if len(statusMap) != 3 {
		t.Errorf("expected 3 statuses, got %d", len(statusMap))
	}
	for id, status := range statusMap {
		if status != models.AccountStatusOnline {
			t.Errorf("account %s: expected online, got %s", id, status)
		}
	}

	if got := sm.OverallStatus(); got != models.CheckStatusOK {
		t.Errorf("expected ok, got %s", got)
	}
}

func TestStatusMonitor_SomeOffline(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	acct, _ := mgr.Account("gmail-1")
	acct.setStatus(models.AccountStatusOnline, "")
	// icloud-1 and ms-1 remain offline (default)

	sm := NewStatusMonitor(mgr)

	if got := sm.OverallStatus(); got != models.HealthStatusDegraded {
		t.Errorf("expected degraded, got %s", got)
	}
}

func TestStatusMonitor_AllOffline(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())
	// All default to offline

	sm := NewStatusMonitor(mgr)

	if got := sm.OverallStatus(); got != models.CheckStatusError {
		t.Errorf("expected error, got %s", got)
	}
}

func TestStatusMonitor_NoAccounts(t *testing.T) {
	mgr, _ := NewManager(nil, zerolog.Nop())
	sm := NewStatusMonitor(mgr)

	if got := sm.OverallStatus(); got != models.CheckStatusOK {
		t.Errorf("expected ok with no accounts, got %s", got)
	}
}

func TestStatusMonitor_SyncingCountsAsOK(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	for _, id := range []string{"gmail-1", "icloud-1", "ms-1"} {
		acct, _ := mgr.Account(id)
		acct.setStatus(models.AccountStatusSyncing, "initial sync")
	}

	sm := NewStatusMonitor(mgr)

	if got := sm.OverallStatus(); got != models.CheckStatusOK {
		t.Errorf("syncing should count as ok, got %s", got)
	}
}

func TestStatusMonitor_HealthStatus(t *testing.T) {
	tests := []struct {
		name       string
		dbOK       bool
		setupFunc  func(mgr *Manager)
		wantHealth string
	}{
		{
			"db down",
			false,
			func(mgr *Manager) {},
			models.HealthStatusUnhealthy,
		},
		{
			"all online",
			true,
			func(mgr *Manager) {
				for _, id := range []string{"gmail-1", "icloud-1", "ms-1"} {
					acct, _ := mgr.Account(id)
					acct.setStatus(models.AccountStatusOnline, "")
				}
			},
			models.HealthStatusHealthy,
		},
		{
			"some offline",
			true,
			func(mgr *Manager) {
				acct, _ := mgr.Account("gmail-1")
				acct.setStatus(models.AccountStatusOnline, "")
			},
			models.HealthStatusDegraded,
		},
		{
			"all imap offline",
			true,
			func(mgr *Manager) {
				// all default offline
			},
			models.HealthStatusUnhealthy,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mgr, _ := NewManager(testAccounts(), zerolog.Nop())
			tt.setupFunc(mgr)
			sm := NewStatusMonitor(mgr)

			got := sm.HealthStatus(tt.dbOK)
			if got != tt.wantHealth {
				t.Errorf("expected %s, got %s", tt.wantHealth, got)
			}
		})
	}
}

func TestStatusMonitor_ErrorStatus(t *testing.T) {
	mgr, _ := NewManager(testAccounts(), zerolog.Nop())

	acct, _ := mgr.Account("gmail-1")
	acct.setStatus(models.AccountStatusError, "auth failure")
	acct2, _ := mgr.Account("icloud-1")
	acct2.setStatus(models.AccountStatusOnline, "")
	acct3, _ := mgr.Account("ms-1")
	acct3.setStatus(models.AccountStatusOnline, "")

	sm := NewStatusMonitor(mgr)

	if got := sm.OverallStatus(); got != models.HealthStatusDegraded {
		t.Errorf("expected degraded with one error account, got %s", got)
	}

	statusMap := sm.AccountStatusMap()
	if statusMap["gmail-1"] != models.AccountStatusError {
		t.Errorf("expected error for gmail-1, got %s", statusMap["gmail-1"])
	}
}
