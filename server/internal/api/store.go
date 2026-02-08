package api

import (
	"context"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/cullenbmacdonald/emailer/internal/storage"
)

// EmailStore defines the storage operations needed by email handlers.
type EmailStore interface {
	ListEmails(ctx context.Context, opts storage.EmailListOptions) (*models.EmailListResponse, error)
	GetEmail(ctx context.Context, id string) (*models.Email, error)
	GetEmailDetail(ctx context.Context, id string) (*models.EmailDetail, error)
	UpdateEmail(ctx context.Context, id string, update models.EmailUpdateRequest) (*models.Email, error)
	DeleteEmail(ctx context.Context, id string) error
	CountEmailsByView(ctx context.Context, accountID string) (*models.AccountCounts, error)
}

// ClassificationStore defines the storage operations needed by reclassify handlers.
type ClassificationStore interface {
	GetClassification(ctx context.Context, emailID string) (*models.Classification, error)
	UpdateClassification(ctx context.Context, emailID string, c *models.Classification) error
	RecordTrainingSignal(ctx context.Context, emailID, previousClass, newClass string, isConfirm bool) error
}

// SnoozeStore defines the storage operations needed by snooze handlers.
type SnoozeStore interface {
	CreateSnooze(ctx context.Context, emailID string, returnAt time.Time, snoozeCount int) (*models.SnoozeState, error)
	GetActiveSnooze(ctx context.Context, emailID string) (*models.SnoozeState, error)
	DeactivateSnooze(ctx context.Context, emailID string) error
}

// AccountStore defines the storage operations needed by account handlers.
type AccountStore interface {
	ListAccounts(ctx context.Context) ([]models.Account, error)
	GetAccount(ctx context.Context, id string) (*models.Account, error)
}

// SearchStore defines the storage operations needed by search handlers.
type SearchStore interface {
	SearchEmails(ctx context.Context, query string, accountID string, cursor string, limit int) (*models.SearchResponse, error)
}

// RecommendationStore defines the storage operations needed by recommendation handlers.
type RecommendationStore interface {
	ListRecommendations(ctx context.Context, opts storage.RecommendationListOptions) (*models.RecommendationListResponse, error)
	GetRecommendation(ctx context.Context, id string) (*models.RecommendationDetail, error)
	CreateRecommendation(ctx context.Context, r *models.Recommendation) (*models.Recommendation, error)
	UpdateRecommendationStatus(ctx context.Context, id, status string) error
}

// DigestStore defines the storage operations needed by digest handlers.
type DigestStore interface {
	ListDigests(ctx context.Context, cursor string, limit int) (*models.DigestListResponse, error)
	GetLatestDigest(ctx context.Context, digestType string) (*models.DailyDigest, error)
	GetDigest(ctx context.Context, id string) (*models.DailyDigest, error)
	UpdateDigest(ctx context.Context, id string, update models.DigestUpdateRequest) error
}

// VIPStore defines the storage operations needed by VIP handlers.
type VIPStore interface {
	ListVIPSenders(ctx context.Context) ([]models.VIPSender, error)
	AddVIPSender(ctx context.Context, email, name string) (*models.VIPSender, error)
	RemoveVIPSender(ctx context.Context, id string) error
}

// ComposeStore defines the storage operations needed by compose handlers.
type ComposeStore interface {
	ListDrafts(ctx context.Context, cursor string, limit int) (*models.DraftListResponse, error)
	CreateDraft(ctx context.Context, d *models.Draft) (*models.Draft, error)
	UpdateDraft(ctx context.Context, id string, d *models.Draft) (*models.Draft, error)
	DeleteDraft(ctx context.Context, id string) error
}

// EmailSender defines the interface for sending emails via SMTP.
type EmailSender interface {
	Send(ctx context.Context, accountID string, compose models.ComposeRequest) (*models.ComposeSendResponse, error)
}
