package storage

import (
	"context"
	"fmt"

	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

// AccountStore provides CRUD operations for the accounts table.
type AccountStore struct {
	pool *pgxpool.Pool
}

// NewAccountStore creates a new AccountStore.
func NewAccountStore(pool *pgxpool.Pool) *AccountStore {
	return &AccountStore{pool: pool}
}

// ListAccounts returns all accounts.
func (s *AccountStore) ListAccounts(ctx context.Context) ([]models.Account, error) {
	query := `
		SELECT id, name, email, COALESCE(type, 'personal'), color, created_at, updated_at
		FROM accounts
		ORDER BY name ASC`

	rows, err := s.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("list accounts: %w", err)
	}
	defer rows.Close()

	var accounts []models.Account
	for rows.Next() {
		var a models.Account
		if err := rows.Scan(&a.ID, &a.Name, &a.EmailAddress, &a.AccountType, &a.Color, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan account: %w", err)
		}
		// Default status to offline until IMAP manager reports otherwise
		a.Status = models.AccountStatusOffline
		accounts = append(accounts, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate accounts: %w", err)
	}

	if accounts == nil {
		accounts = []models.Account{}
	}
	return accounts, nil
}

// GetAccount returns a single account by ID.
func (s *AccountStore) GetAccount(ctx context.Context, id string) (*models.Account, error) {
	query := `
		SELECT id, name, email, COALESCE(type, 'personal'), color, created_at, updated_at
		FROM accounts
		WHERE id = $1`

	var a models.Account
	err := s.pool.QueryRow(ctx, query, id).Scan(
		&a.ID, &a.Name, &a.EmailAddress, &a.AccountType, &a.Color, &a.CreatedAt, &a.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get account %s: %w", id, err)
	}
	a.Status = models.AccountStatusOffline
	return &a, nil
}
