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
