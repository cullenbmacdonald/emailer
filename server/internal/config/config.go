// Package config handles loading and validating server configuration
// from a YAML file with environment variable overrides.
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

// Config is the top-level server configuration.
type Config struct {
	API            APIConfig            `yaml:"api"`
	Database       DatabaseConfig       `yaml:"database"`
	Accounts       []AccountConfig      `yaml:"accounts"`
	LLM            LLMConfig            `yaml:"llm"`
	Classification ClassificationConfig `yaml:"classification"`
	Digest         DigestConfig         `yaml:"digest"`
	Cleanup        CleanupConfig        `yaml:"cleanup"`
	Sync           SyncConfig           `yaml:"sync"`
	Logging        LoggingConfig        `yaml:"logging"`
}

// APIConfig holds HTTP server settings.
type APIConfig struct {
	Port      string   `yaml:"port"`
	AuthToken string   `yaml:"auth_token"`
	CORSOrig  []string `yaml:"cors_origins"`
}

// DatabaseConfig holds PostgreSQL connection settings.
type DatabaseConfig struct {
	DSN         string `yaml:"dsn"`
	MaxConns    int32  `yaml:"max_conns"`
	MinConns    int32  `yaml:"min_conns"`
	MaxConnIdle string `yaml:"max_conn_idle_time"`
	MaxConnLife string `yaml:"max_conn_lifetime"`
}

// AccountConfig holds email account settings.
type AccountConfig struct {
	ID          string      `yaml:"id"`
	Name        string      `yaml:"name"`
	Email       string      `yaml:"email"`
	Provider    string      `yaml:"provider"`
	AccountType string      `yaml:"type"`
	Color       string      `yaml:"color"`
	IMAP        IMAPConfig  `yaml:"imap"`
	SMTP        SMTPConfig  `yaml:"smtp"`
	OAuth       OAuthConfig `yaml:"oauth"`
	AppPassword string      `yaml:"app_password"`
}

// IMAPConfig holds IMAP server settings.
type IMAPConfig struct {
	Host string `yaml:"host"`
	Port int    `yaml:"port"`
}

// SMTPConfig holds SMTP server settings.
type SMTPConfig struct {
	Host string `yaml:"host"`
	Port int    `yaml:"port"`
}

// OAuthConfig holds OAuth2 credentials.
type OAuthConfig struct {
	ClientID     string `yaml:"client_id"`
	ClientSecret string `yaml:"client_secret"`
	TenantID     string `yaml:"tenant_id"`
	TokenFile    string `yaml:"token_file"`
}

// LLMConfig holds LLM provider settings.
type LLMConfig struct {
	Provider  string          `yaml:"provider"`
	Ollama    OllamaConfig    `yaml:"ollama"`
	Anthropic AnthropicConfig `yaml:"anthropic"`
	OpenAI    OpenAIConfig    `yaml:"openai"`
	LMStudio  LMStudioConfig  `yaml:"lmstudio"`
}

// OllamaConfig holds Ollama-specific settings.
type OllamaConfig struct {
	BaseURL string `yaml:"base_url"`
	Model   string `yaml:"model"`
}

// LMStudioConfig holds LM Studio-specific settings.
type LMStudioConfig struct {
	BaseURL string `yaml:"base_url"`
	Model   string `yaml:"model"`
}

// AnthropicConfig holds Anthropic-specific settings.
type AnthropicConfig struct {
	APIKey string `yaml:"api_key"`
	Model  string `yaml:"model"`
}

// OpenAIConfig holds OpenAI-specific settings.
type OpenAIConfig struct {
	APIKey string `yaml:"api_key"`
	Model  string `yaml:"model"`
}

// ClassificationConfig holds classification pipeline thresholds.
type ClassificationConfig struct {
	ActionConfidenceThreshold  float64 `yaml:"action_confidence_threshold"`
	GeneralConfidenceThreshold float64 `yaml:"general_confidence_threshold"`
	LLMFallbackThreshold       float64 `yaml:"llm_fallback_threshold"`
}

// DigestConfig holds daily digest scheduling settings.
type DigestConfig struct {
	MorningTime string `yaml:"morning_time"`
	EveningTime string `yaml:"evening_time"`
	Timezone    string `yaml:"timezone"`
}

// CleanupConfig holds auto-cleanup settings.
type CleanupConfig struct {
	FilteredRetentionDays int `yaml:"filtered_retention_days"`
}

// SyncConfig holds IMAP sync timing settings.
type SyncConfig struct {
	IMAPIdleRestartMinutes int `yaml:"imap_idle_restart_minutes"`
	FolderPollMinutes      int `yaml:"folder_poll_minutes"`
	FullResyncMinutes      int `yaml:"full_resync_minutes"`
}

// LoggingConfig holds logging settings.
type LoggingConfig struct {
	Level string `yaml:"level"`
	File  string `yaml:"file"`
}

// Defaults returns a Config populated with sensible default values.
func Defaults() Config {
	return Config{
		API: APIConfig{
			Port: "8080",
		},
		Database: DatabaseConfig{
			MaxConns:    10,
			MinConns:    2,
			MaxConnIdle: "5m",
			MaxConnLife: "1h",
		},
		LLM: LLMConfig{
			Provider: "ollama",
			Ollama: OllamaConfig{
				BaseURL: "http://localhost:11434",
				Model:   "qwen2.5:7b",
			},
		},
		Classification: ClassificationConfig{
			ActionConfidenceThreshold:  0.6,
			GeneralConfidenceThreshold: 0.85,
			LLMFallbackThreshold:       0.85,
		},
		Digest: DigestConfig{
			MorningTime: "06:00",
			EveningTime: "19:00",
			Timezone:    "America/Los_Angeles",
		},
		Cleanup: CleanupConfig{
			FilteredRetentionDays: 14,
		},
		Sync: SyncConfig{
			IMAPIdleRestartMinutes: 14,
			FolderPollMinutes:      5,
			FullResyncMinutes:      30,
		},
		Logging: LoggingConfig{
			Level: "info",
		},
	}
}

// Load reads configuration from a YAML file and applies environment
// variable overrides. If path is empty, only defaults and env vars are used.
func Load(path string) (*Config, error) {
	cfg := Defaults()

	if path != "" {
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("reading config file %s: %w", path, err)
		}
		if err := yaml.Unmarshal(data, &cfg); err != nil {
			return nil, fmt.Errorf("parsing config file %s: %w", path, err)
		}
	}

	applyEnvOverrides(&cfg)

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("config validation: %w", err)
	}

	return &cfg, nil
}

// applyEnvOverrides applies environment variable overrides to the config.
// Environment variables take precedence over file values.
func applyEnvOverrides(cfg *Config) {
	if v := os.Getenv("EMAILER_PORT"); v != "" {
		cfg.API.Port = v
	}
	if v := os.Getenv("EMAILER_AUTH_TOKEN"); v != "" {
		cfg.API.AuthToken = v
	}
	if v := os.Getenv("EMAILER_DB_DSN"); v != "" {
		cfg.Database.DSN = v
	}
	if v := os.Getenv("EMAILER_LLM_PROVIDER"); v != "" {
		cfg.LLM.Provider = v
	}
	if v := os.Getenv("EMAILER_ANTHROPIC_API_KEY"); v != "" {
		cfg.LLM.Anthropic.APIKey = v
	}
	if v := os.Getenv("EMAILER_OPENAI_API_KEY"); v != "" {
		cfg.LLM.OpenAI.APIKey = v
	}
	if v := os.Getenv("EMAILER_LOG_LEVEL"); v != "" {
		cfg.Logging.Level = v
	}
}

// Validate checks that all required configuration fields are set and
// returns an error describing the first missing or invalid field.
func (c *Config) Validate() error {
	if c.API.Port == "" {
		return fmt.Errorf("missing required field: api.port")
	}

	port, err := strconv.Atoi(c.API.Port)
	if err != nil || port < 1 || port > 65535 {
		return fmt.Errorf("invalid field api.port: must be a number between 1 and 65535")
	}

	if c.API.AuthToken == "" {
		return fmt.Errorf("missing required field: api.auth_token")
	}

	if c.Logging.Level != "" {
		validLevels := map[string]bool{
			"debug": true, "info": true, "warn": true, "error": true,
		}
		if !validLevels[strings.ToLower(c.Logging.Level)] {
			return fmt.Errorf("invalid field logging.level: must be one of debug, info, warn, error")
		}
	}

	if c.Digest.Timezone != "" {
		if _, err := time.LoadLocation(c.Digest.Timezone); err != nil {
			return fmt.Errorf("invalid field digest.timezone: %w", err)
		}
	}

	if c.Classification.ActionConfidenceThreshold < 0 || c.Classification.ActionConfidenceThreshold > 1 {
		return fmt.Errorf("invalid field classification.action_confidence_threshold: must be between 0 and 1")
	}
	if c.Classification.GeneralConfidenceThreshold < 0 || c.Classification.GeneralConfidenceThreshold > 1 {
		return fmt.Errorf("invalid field classification.general_confidence_threshold: must be between 0 and 1")
	}
	if c.Classification.LLMFallbackThreshold < 0 || c.Classification.LLMFallbackThreshold > 1 {
		return fmt.Errorf("invalid field classification.llm_fallback_threshold: must be between 0 and 1")
	}

	if c.Cleanup.FilteredRetentionDays < 1 {
		return fmt.Errorf("invalid field cleanup.filtered_retention_days: must be at least 1")
	}

	return nil
}

// Address returns the full listen address (e.g., ":8080").
func (c *Config) Address() string {
	return ":" + c.API.Port
}
