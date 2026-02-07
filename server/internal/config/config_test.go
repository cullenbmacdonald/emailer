package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaults(t *testing.T) {
	cfg := Defaults()

	if cfg.API.Port != "8080" {
		t.Errorf("expected default port 8080, got %s", cfg.API.Port)
	}
	if cfg.Database.MaxConns != 10 {
		t.Errorf("expected default max_conns 10, got %d", cfg.Database.MaxConns)
	}
	if cfg.Database.MinConns != 2 {
		t.Errorf("expected default min_conns 2, got %d", cfg.Database.MinConns)
	}
	if cfg.LLM.Provider != "ollama" {
		t.Errorf("expected default LLM provider ollama, got %s", cfg.LLM.Provider)
	}
	if cfg.Classification.ActionConfidenceThreshold != 0.6 {
		t.Errorf("expected default action threshold 0.6, got %f", cfg.Classification.ActionConfidenceThreshold)
	}
	if cfg.Cleanup.FilteredRetentionDays != 14 {
		t.Errorf("expected default retention days 14, got %d", cfg.Cleanup.FilteredRetentionDays)
	}
	if cfg.Sync.IMAPIdleRestartMinutes != 14 {
		t.Errorf("expected default idle restart 14, got %d", cfg.Sync.IMAPIdleRestartMinutes)
	}
	if cfg.Logging.Level != "info" {
		t.Errorf("expected default log level info, got %s", cfg.Logging.Level)
	}
}

func TestLoadFromYAML(t *testing.T) {
	yamlContent := `
api:
  port: "9090"
  auth_token: "test-token-123"
  cors_origins:
    - "http://localhost:3000"
database:
  dsn: "postgres://user:pass@localhost:5432/emailer"
  max_conns: 20
  min_conns: 5
llm:
  provider: "anthropic"
classification:
  action_confidence_threshold: 0.7
  general_confidence_threshold: 0.9
  llm_fallback_threshold: 0.8
digest:
  morning_time: "07:00"
  evening_time: "20:00"
  timezone: "America/New_York"
cleanup:
  filtered_retention_days: 7
sync:
  imap_idle_restart_minutes: 10
  folder_poll_minutes: 3
  full_resync_minutes: 15
logging:
  level: "debug"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.API.Port != "9090" {
		t.Errorf("expected port 9090, got %s", cfg.API.Port)
	}
	if cfg.API.AuthToken != "test-token-123" {
		t.Errorf("expected auth token test-token-123, got %s", cfg.API.AuthToken)
	}
	if cfg.Database.DSN != "postgres://user:pass@localhost:5432/emailer" {
		t.Errorf("expected DSN, got %s", cfg.Database.DSN)
	}
	if cfg.Database.MaxConns != 20 {
		t.Errorf("expected max_conns 20, got %d", cfg.Database.MaxConns)
	}
	if cfg.LLM.Provider != "anthropic" {
		t.Errorf("expected LLM provider anthropic, got %s", cfg.LLM.Provider)
	}
	if cfg.Classification.ActionConfidenceThreshold != 0.7 {
		t.Errorf("expected action threshold 0.7, got %f", cfg.Classification.ActionConfidenceThreshold)
	}
	if cfg.Digest.Timezone != "America/New_York" {
		t.Errorf("expected timezone America/New_York, got %s", cfg.Digest.Timezone)
	}
	if cfg.Cleanup.FilteredRetentionDays != 7 {
		t.Errorf("expected retention days 7, got %d", cfg.Cleanup.FilteredRetentionDays)
	}
	if cfg.Sync.IMAPIdleRestartMinutes != 10 {
		t.Errorf("expected idle restart 10, got %d", cfg.Sync.IMAPIdleRestartMinutes)
	}
	if cfg.Logging.Level != "debug" {
		t.Errorf("expected log level debug, got %s", cfg.Logging.Level)
	}
	if len(cfg.API.CORSOrig) != 1 || cfg.API.CORSOrig[0] != "http://localhost:3000" {
		t.Errorf("expected cors origins [http://localhost:3000], got %v", cfg.API.CORSOrig)
	}
}

func TestLoadEnvOverrides(t *testing.T) {
	yamlContent := `
api:
  port: "9090"
  auth_token: "file-token"
database:
  dsn: "postgres://file@localhost/db"
llm:
  provider: "ollama"
logging:
  level: "info"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	// Set env vars that should override file values
	t.Setenv("EMAILER_PORT", "3000")
	t.Setenv("EMAILER_AUTH_TOKEN", "env-token")
	t.Setenv("EMAILER_DB_DSN", "postgres://env@localhost/db")
	t.Setenv("EMAILER_LLM_PROVIDER", "anthropic")

	cfg, err := Load(path)
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if cfg.API.Port != "3000" {
		t.Errorf("expected env override port 3000, got %s", cfg.API.Port)
	}
	if cfg.API.AuthToken != "env-token" {
		t.Errorf("expected env override auth token, got %s", cfg.API.AuthToken)
	}
	if cfg.Database.DSN != "postgres://env@localhost/db" {
		t.Errorf("expected env override DSN, got %s", cfg.Database.DSN)
	}
	if cfg.LLM.Provider != "anthropic" {
		t.Errorf("expected env override LLM provider, got %s", cfg.LLM.Provider)
	}
}

func TestValidationMissingAuthToken(t *testing.T) {
	yamlContent := `
api:
  port: "8080"
logging:
  level: "info"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	// Make sure env var is not set
	t.Setenv("EMAILER_AUTH_TOKEN", "")

	_, err := Load(path)
	if err == nil {
		t.Fatal("expected validation error for missing auth_token, got nil")
	}
	if got := err.Error(); !contains(got, "api.auth_token") {
		t.Errorf("expected error to mention api.auth_token, got: %s", got)
	}
}

func TestValidationInvalidPort(t *testing.T) {
	tests := []struct {
		name string
		port string
	}{
		{"not a number", "abc"},
		{"zero", "0"},
		{"negative", "-1"},
		{"too high", "99999"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			yamlContent := `
api:
  port: "` + tt.port + `"
  auth_token: "test"
logging:
  level: "info"
`
			dir := t.TempDir()
			path := filepath.Join(dir, "config.yaml")
			if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
				t.Fatalf("writing temp config: %v", err)
			}

			_, err := Load(path)
			if err == nil {
				t.Fatalf("expected validation error for port %q, got nil", tt.port)
			}
			if got := err.Error(); !contains(got, "api.port") {
				t.Errorf("expected error to mention api.port, got: %s", got)
			}
		})
	}
}

func TestValidationInvalidLogLevel(t *testing.T) {
	yamlContent := `
api:
  port: "8080"
  auth_token: "test"
logging:
  level: "verbose"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	_, err := Load(path)
	if err == nil {
		t.Fatal("expected validation error for invalid log level, got nil")
	}
	if got := err.Error(); !contains(got, "logging.level") {
		t.Errorf("expected error to mention logging.level, got: %s", got)
	}
}

func TestValidationInvalidTimezone(t *testing.T) {
	yamlContent := `
api:
  port: "8080"
  auth_token: "test"
digest:
  timezone: "Not/A/Timezone"
logging:
  level: "info"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	_, err := Load(path)
	if err == nil {
		t.Fatal("expected validation error for invalid timezone, got nil")
	}
	if got := err.Error(); !contains(got, "digest.timezone") {
		t.Errorf("expected error to mention digest.timezone, got: %s", got)
	}
}

func TestValidationInvalidThresholds(t *testing.T) {
	tests := []struct {
		name  string
		yaml  string
		field string
	}{
		{
			name: "action threshold too high",
			yaml: `
api:
  port: "8080"
  auth_token: "test"
classification:
  action_confidence_threshold: 1.5
logging:
  level: "info"
`,
			field: "classification.action_confidence_threshold",
		},
		{
			name: "general threshold negative",
			yaml: `
api:
  port: "8080"
  auth_token: "test"
classification:
  general_confidence_threshold: -0.1
logging:
  level: "info"
`,
			field: "classification.general_confidence_threshold",
		},
		{
			name: "llm threshold too high",
			yaml: `
api:
  port: "8080"
  auth_token: "test"
classification:
  llm_fallback_threshold: 2.0
logging:
  level: "info"
`,
			field: "classification.llm_fallback_threshold",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			path := filepath.Join(dir, "config.yaml")
			if err := os.WriteFile(path, []byte(tt.yaml), 0o644); err != nil {
				t.Fatalf("writing temp config: %v", err)
			}

			_, err := Load(path)
			if err == nil {
				t.Fatalf("expected validation error for %s, got nil", tt.field)
			}
			if got := err.Error(); !contains(got, tt.field) {
				t.Errorf("expected error to mention %s, got: %s", tt.field, got)
			}
		})
	}
}

func TestValidationInvalidRetention(t *testing.T) {
	yamlContent := `
api:
  port: "8080"
  auth_token: "test"
cleanup:
  filtered_retention_days: 0
logging:
  level: "info"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	_, err := Load(path)
	if err == nil {
		t.Fatal("expected validation error for retention days, got nil")
	}
	if got := err.Error(); !contains(got, "cleanup.filtered_retention_days") {
		t.Errorf("expected error to mention cleanup.filtered_retention_days, got: %s", got)
	}
}

func TestLoadNonexistentFile(t *testing.T) {
	_, err := Load("/nonexistent/path/config.yaml")
	if err == nil {
		t.Fatal("expected error for nonexistent file, got nil")
	}
}

func TestLoadInvalidYAML(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte("{{{{not yaml"), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	_, err := Load(path)
	if err == nil {
		t.Fatal("expected error for invalid YAML, got nil")
	}
}

func TestLoadEmptyPath(t *testing.T) {
	// Loading with empty path should use defaults + env vars
	t.Setenv("EMAILER_AUTH_TOKEN", "env-only-token")

	cfg, err := Load("")
	if err != nil {
		t.Fatalf("Load('') error: %v", err)
	}

	if cfg.API.Port != "8080" {
		t.Errorf("expected default port 8080, got %s", cfg.API.Port)
	}
	if cfg.API.AuthToken != "env-only-token" {
		t.Errorf("expected env auth token, got %s", cfg.API.AuthToken)
	}
}

func TestAddress(t *testing.T) {
	cfg := &Config{
		API: APIConfig{Port: "9090"},
	}
	if got := cfg.Address(); got != ":9090" {
		t.Errorf("expected :9090, got %s", got)
	}
}

func TestLoadWithAccountConfig(t *testing.T) {
	yamlContent := `
api:
  port: "8080"
  auth_token: "test"
accounts:
  - id: "personal-gmail"
    name: "Personal Gmail"
    email: "user@gmail.com"
    provider: "gmail"
    type: "personal"
    color: "#34A853"
    imap:
      host: "imap.gmail.com"
      port: 993
    smtp:
      host: "smtp.gmail.com"
      port: 587
    oauth:
      client_id: "test-client-id"
      client_secret: "test-secret"
      token_file: "/tmp/token.json"
  - id: "icloud"
    name: "iCloud"
    email: "user@icloud.com"
    provider: "icloud"
    type: "personal"
    color: "#FF9500"
    imap:
      host: "imap.mail.me.com"
      port: 993
    smtp:
      host: "smtp.mail.me.com"
      port: 587
    app_password: "xxxx-xxxx-xxxx-xxxx"
logging:
  level: "info"
`
	dir := t.TempDir()
	path := filepath.Join(dir, "config.yaml")
	if err := os.WriteFile(path, []byte(yamlContent), 0o644); err != nil {
		t.Fatalf("writing temp config: %v", err)
	}

	cfg, err := Load(path)
	if err != nil {
		t.Fatalf("Load() error: %v", err)
	}

	if len(cfg.Accounts) != 2 {
		t.Fatalf("expected 2 accounts, got %d", len(cfg.Accounts))
	}

	gmail := cfg.Accounts[0]
	if gmail.ID != "personal-gmail" {
		t.Errorf("expected account ID personal-gmail, got %s", gmail.ID)
	}
	if gmail.Provider != "gmail" {
		t.Errorf("expected provider gmail, got %s", gmail.Provider)
	}
	if gmail.IMAP.Host != "imap.gmail.com" {
		t.Errorf("expected IMAP host imap.gmail.com, got %s", gmail.IMAP.Host)
	}
	if gmail.IMAP.Port != 993 {
		t.Errorf("expected IMAP port 993, got %d", gmail.IMAP.Port)
	}
	if gmail.OAuth.ClientID != "test-client-id" {
		t.Errorf("expected OAuth client_id, got %s", gmail.OAuth.ClientID)
	}

	icloud := cfg.Accounts[1]
	if icloud.AppPassword != "xxxx-xxxx-xxxx-xxxx" {
		t.Errorf("expected app password, got %s", icloud.AppPassword)
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
