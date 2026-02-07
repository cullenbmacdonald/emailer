package imap

import (
	"bytes"
	"context"
	"fmt"
	"time"

	"github.com/emersion/go-imap/v2"
	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/rs/zerolog"

	"github.com/cullenbmacdonald/emailer/internal/models"
)

// FetchResult holds the parsed data from a single fetched IMAP message.
type FetchResult struct {
	UID       imap.UID
	MessageID string
	ThreadID  string
	Email     *models.Email
	HTMLBody  string
	TextBody  string
}

// FetchNewUIDs fetches full messages for the given UIDs from the IMAP server,
// parses them, and returns structured results ready for storage.
func FetchNewUIDs(ctx context.Context, client *imapclient.Client, uids []imap.UID, accountCfg AccountFetchConfig, logger zerolog.Logger) ([]*FetchResult, error) {
	if len(uids) == 0 {
		return nil, nil
	}

	uidSet := buildUIDSet(uids)

	fetchOpts := &imap.FetchOptions{
		Envelope:      true,
		Flags:         true,
		InternalDate:  true,
		UID:           true,
		BodyStructure: &imap.FetchItemBodyStructure{Extended: true},
		BodySection:   []*imap.FetchItemBodySection{{Peek: true}}, // Fetch full RFC822 body without marking \Seen
	}

	fetchCmd := client.Fetch(uidSet, fetchOpts)
	defer func() { _ = fetchCmd.Close() }()

	var results []*FetchResult

	for {
		if ctx.Err() != nil {
			return results, ctx.Err()
		}

		msg := fetchCmd.Next()
		if msg == nil {
			break
		}

		buf, err := msg.Collect()
		if err != nil {
			logger.Warn().Err(err).Msg("failed to collect fetch message data")
			continue
		}

		result, err := processFetchedMessage(buf, accountCfg, logger)
		if err != nil {
			logger.Warn().Err(err).Uint32("uid", uint32(buf.UID)).Msg("failed to process fetched message, storing partial data")
			// Store what we can with partial data.
			result = buildPartialResult(buf, accountCfg)
		}

		results = append(results, result)
	}

	if err := fetchCmd.Close(); err != nil {
		return results, fmt.Errorf("fetch command: %w", err)
	}

	return results, nil
}

// AccountFetchConfig provides account context for building fetch results.
type AccountFetchConfig struct {
	AccountID    string
	AccountName  string
	AccountColor string
}

// processFetchedMessage converts a single FetchMessageBuffer into a FetchResult.
func processFetchedMessage(buf *imapclient.FetchMessageBuffer, cfg AccountFetchConfig, logger zerolog.Logger) (*FetchResult, error) {
	env := buf.Envelope
	if env == nil {
		return nil, fmt.Errorf("no envelope in fetch response for UID %d", buf.UID)
	}

	// Find the full body section.
	var bodyBytes []byte
	for _, section := range buf.BodySection {
		bodyBytes = section.Bytes
		break
	}

	var parsed *ParsedEmail
	if len(bodyBytes) > 0 {
		var err error
		parsed, err = ParseMIME(bytes.NewReader(bodyBytes))
		if err != nil {
			logger.Warn().Err(err).Str("message_id", env.MessageID).Msg("MIME parse error, using envelope only")
		}
	}

	if parsed == nil {
		parsed = &ParsedEmail{}
	}

	email := &models.Email{
		AccountID:      cfg.AccountID,
		MessageID:      env.MessageID,
		From:           convertAddress(env.From),
		To:             convertAddresses(env.To),
		CC:             convertAddresses(env.Cc),
		Subject:        env.Subject,
		Snippet:        parsed.Snippet,
		ReceivedAt:     resolveDate(env.Date, buf.InternalDate),
		HasAttachments: len(parsed.Attachments) > 0,
		IsRead:         hasFlag(buf.Flags, imap.FlagSeen),
		AccountName:    cfg.AccountName,
		AccountColor:   cfg.AccountColor,
	}

	// Use In-Reply-To as a basic thread ID if no explicit thread ID is available.
	threadID := ""
	if len(env.InReplyTo) > 0 {
		threadID = env.InReplyTo[0]
	}

	return &FetchResult{
		UID:       buf.UID,
		MessageID: env.MessageID,
		ThreadID:  threadID,
		Email:     email,
		HTMLBody:  parsed.HTMLBody,
		TextBody:  parsed.TextBody,
	}, nil
}

// buildPartialResult creates a minimal FetchResult when MIME parsing fails.
func buildPartialResult(buf *imapclient.FetchMessageBuffer, cfg AccountFetchConfig) *FetchResult {
	email := &models.Email{
		AccountID:  cfg.AccountID,
		IsRead:     hasFlag(buf.Flags, imap.FlagSeen),
		ReceivedAt: buf.InternalDate,
	}

	messageID := ""
	if buf.Envelope != nil {
		email.Subject = buf.Envelope.Subject
		email.From = convertAddress(buf.Envelope.From)
		email.To = convertAddresses(buf.Envelope.To)
		email.CC = convertAddresses(buf.Envelope.Cc)
		messageID = buf.Envelope.MessageID
	}

	return &FetchResult{
		UID:       buf.UID,
		MessageID: messageID,
		Email:     email,
	}
}

// convertAddress converts a list of IMAP addresses to a single Contact (first address).
func convertAddress(addrs []imap.Address) models.Contact {
	if len(addrs) == 0 {
		return models.Contact{}
	}
	return models.Contact{
		Name:  addrs[0].Name,
		Email: addrs[0].Addr(),
	}
}

// convertAddresses converts IMAP addresses to model Contacts.
func convertAddresses(addrs []imap.Address) []models.Contact {
	if len(addrs) == 0 {
		return nil
	}
	contacts := make([]models.Contact, 0, len(addrs))
	for _, a := range addrs {
		if a.Addr() == "" {
			continue // Skip group markers.
		}
		contacts = append(contacts, models.Contact{
			Name:  a.Name,
			Email: a.Addr(),
		})
	}
	return contacts
}

// resolveDate returns the envelope date, falling back to IMAP internal date.
func resolveDate(envDate, internalDate time.Time) time.Time {
	if !envDate.IsZero() {
		return envDate
	}
	return internalDate
}

// hasFlag checks if a flag list contains a specific flag.
func hasFlag(flags []imap.Flag, target imap.Flag) bool {
	for _, f := range flags {
		if f == target {
			return true
		}
	}
	return false
}

// buildUIDSet creates a UIDSet from a slice of UIDs.
func buildUIDSet(uids []imap.UID) imap.UIDSet {
	var set imap.UIDSet
	for _, uid := range uids {
		set.AddNum(uid)
	}
	return set
}
