package imap

import (
	"context"
	"fmt"
	"time"

	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/classifier"
	"github.com/cullenbmacdonald/emailer/internal/models"
)

// SyncResult holds the outcome of a sync operation.
type SyncResult struct {
	AccountID string
	Folder    string
	NewCount  int
	SkipCount int
	Errors    int
}

// Classifier is the interface for email classification.
type Classifier interface {
	Classify(ctx context.Context, input *classifier.EmailInput) *classifier.ClassificationResult
}

// NewsletterCallback is called when an email is classified as a newsletter.
// It receives the email and its text body for downstream processing (e.g., recommendation extraction).
type NewsletterCallback func(email *models.Email, textBody string)

// EmailSyncer coordinates fetching new emails from IMAP and storing them in the database.
type EmailSyncer struct {
	pool         *pgxpool.Pool
	classifier   Classifier
	onNewsletter NewsletterCallback
	logger       zerolog.Logger
}

// NewEmailSyncer creates a new syncer that stores fetched emails.
func NewEmailSyncer(pool *pgxpool.Pool, logger zerolog.Logger) *EmailSyncer {
	return &EmailSyncer{
		pool:   pool,
		logger: logger.With().Str("component", "syncer").Logger(),
	}
}

// SetClassifier configures the classification pipeline.
func (s *EmailSyncer) SetClassifier(c Classifier) {
	s.classifier = c
}

// SetNewsletterCallback sets a callback invoked when an email is classified as a newsletter.
func (s *EmailSyncer) SetNewsletterCallback(cb NewsletterCallback) {
	s.onNewsletter = cb
}

// SyncFolder fetches new messages from the given folder and stores them.
// It determines which UIDs are new by comparing against what's already stored,
// fetches the new ones, parses them, and inserts into the database.
// Returns parsed emails for downstream processing (e.g., classification).
func (s *EmailSyncer) SyncFolder(ctx context.Context, client *imapclient.Client, folder string, cfg AccountFetchConfig, logger zerolog.Logger) (*SyncResult, []*models.Email, error) {
	result := &SyncResult{
		AccountID: cfg.AccountID,
		Folder:    folder,
	}

	// Get the highest UID we already have for this account+folder.
	lastUID, err := s.getLastStoredUID(ctx, cfg.AccountID, folder)
	if err != nil {
		return result, nil, fmt.Errorf("get last stored UID: %w", err)
	}

	// Search for UIDs greater than our last stored UID.
	newUIDs, err := searchNewUIDs(client, lastUID)
	if err != nil {
		return result, nil, fmt.Errorf("search new UIDs: %w", err)
	}

	if len(newUIDs) == 0 {
		logger.Debug().Str("folder", folder).Msg("no new messages")
		return result, nil, nil
	}

	logger.Info().Str("folder", folder).Int("count", len(newUIDs)).Msg("fetching new messages")

	// Fetch and parse the new messages.
	fetchResults, err := FetchNewUIDs(ctx, client, newUIDs, cfg, logger)
	if err != nil {
		logger.Warn().Err(err).Msg("errors during fetch, storing what we got")
	}

	// Store each fetched email.
	storedEmails := make([]*models.Email, 0, len(fetchResults))
	for _, fr := range fetchResults {
		stored, storeErr := s.storeEmail(ctx, fr, folder)
		if storeErr != nil {
			logger.Warn().Err(storeErr).
				Str("message_id", fr.MessageID).
				Uint32("uid", uint32(fr.UID)).
				Msg("failed to store email")
			result.Errors++
			continue
		}
		if stored == nil {
			result.SkipCount++ // Duplicate.
			continue
		}
		storedEmails = append(storedEmails, stored)
		result.NewCount++

		// Classify the email.
		if s.classifier != nil {
			input := &classifier.EmailInput{
				From:     stored.From,
				To:       stored.To,
				CC:       stored.CC,
				Subject:  stored.Subject,
				TextBody: fr.TextBody,
				HTMLBody: fr.HTMLBody,
			}
			cr := s.classifier.Classify(ctx, input)
			_, classErr := s.pool.Exec(ctx,
				`INSERT INTO classifications (email_id, classification, confidence, classified_by, reason)
				 VALUES ($1, $2, $3, $4, $5)
				 ON CONFLICT (email_id) DO NOTHING`,
				stored.ID, cr.Classification, cr.Confidence, cr.ClassifiedBy, cr.Reason)
			if classErr != nil {
				logger.Warn().Err(classErr).Str("email_id", stored.ID).Msg("failed to store classification")
			} else {
				logger.Info().Str("email_id", stored.ID).Str("class", cr.Classification).Float64("confidence", cr.Confidence).Msg("classified")

				// Queue all emails for recommendation extraction.
				if s.onNewsletter != nil {
					s.onNewsletter(stored, fr.TextBody)
				}
			}
		}
	}

	logger.Info().
		Int("new", result.NewCount).
		Int("skipped", result.SkipCount).
		Int("errors", result.Errors).
		Msg("sync complete")

	return result, storedEmails, nil
}

// getLastStoredUID returns the highest IMAP UID stored for a given account+folder.
func (s *EmailSyncer) getLastStoredUID(ctx context.Context, accountID, folder string) (imap.UID, error) {
	var uid *int
	err := s.pool.QueryRow(ctx,
		`SELECT MAX(uid) FROM emails WHERE account_id = $1 AND folder = $2`,
		accountID, folder,
	).Scan(&uid)
	if err != nil {
		return 0, err
	}
	if uid == nil {
		return 0, nil
	}
	return imap.UID(*uid), nil
}

// searchNewUIDs uses IMAP SEARCH to find UIDs greater than lastUID.
func searchNewUIDs(client *imapclient.Client, lastUID imap.UID) ([]imap.UID, error) {
	// Search for UIDs > lastUID, limited to last 30 days on initial sync.
	var uidSet imap.UIDSet
	if lastUID == 0 {
		uidSet.AddRange(1, 0) // 1:* means all messages.
	} else {
		uidSet.AddRange(lastUID+1, 0) // lastUID+1:* means all after last stored.
	}

	criteria := &imap.SearchCriteria{
		UID: []imap.UIDSet{uidSet},
	}

	// On initial sync, limit to last 90 days.
	if lastUID == 0 {
		since := time.Now().AddDate(0, 0, -90)
		criteria.Since = since
	}

	searchData, err := client.UIDSearch(criteria, nil).Wait()
	if err != nil {
		return nil, fmt.Errorf("UID SEARCH: %w", err)
	}

	return searchData.AllUIDs(), nil
}

// storeEmail inserts a fetched email into the database.
// Returns nil, nil if the email already exists (deduplication by account_id+folder+uid).
func (s *EmailSyncer) storeEmail(ctx context.Context, fr *FetchResult, folder string) (*models.Email, error) {
	email := fr.Email

	// Use ON CONFLICT to handle deduplication at the DB level.
	query := `
		INSERT INTO emails (
			account_id, message_id, thread_id, uid, folder,
			from_address, from_name, to_addresses, cc_addresses,
			subject, snippet, text_body, html_body,
			received_at, has_attachments, is_read, is_archived, labels
		) VALUES (
			$1, $2, $3, $4, $5,
			$6, $7, $8, $9,
			$10, $11, $12, $13,
			$14, $15, $16, $17, $18
		)
		ON CONFLICT (account_id, folder, uid) DO NOTHING
		RETURNING id, created_at, updated_at`

	toJSON, err := marshalContacts(email.To)
	if err != nil {
		return nil, fmt.Errorf("marshal to: %w", err)
	}
	ccJSON, err := marshalContacts(email.CC)
	if err != nil {
		return nil, fmt.Errorf("marshal cc: %w", err)
	}
	labelsJSON, err := marshalLabels(email.Labels)
	if err != nil {
		return nil, fmt.Errorf("marshal labels: %w", err)
	}

	var id string
	var createdAt, updatedAt interface{}
	err = s.pool.QueryRow(ctx, query,
		email.AccountID, fr.MessageID, fr.ThreadID, int(fr.UID), folder,
		email.From.Email, email.From.Name, toJSON, ccJSON,
		email.Subject, email.Snippet, fr.TextBody, fr.HTMLBody,
		email.ReceivedAt, email.HasAttachments, email.IsRead, email.IsArchived, labelsJSON,
	).Scan(&id, &createdAt, &updatedAt)

	if err != nil {
		// ON CONFLICT DO NOTHING returns no rows — pgx returns ErrNoRows.
		if err.Error() == "no rows in result set" {
			return nil, nil // Already exists, skip.
		}
		return nil, fmt.Errorf("insert email: %w", err)
	}

	email.ID = id
	return email, nil
}

// marshalContacts converts contacts to JSON for JSONB storage.
func marshalContacts(contacts []models.Contact) ([]byte, error) {
	if contacts == nil {
		contacts = []models.Contact{}
	}
	return jsonMarshal(contacts)
}

// marshalLabels converts labels to JSON for JSONB storage.
func marshalLabels(labels []string) ([]byte, error) {
	if labels == nil {
		labels = []string{}
	}
	return jsonMarshal(labels)
}
