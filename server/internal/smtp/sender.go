// Package smtp implements email sending via SMTP.
package smtp

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/smtp"
	"strings"
	"time"

	"github.com/cullenbmacdonald/emailer/internal/config"
	"github.com/cullenbmacdonald/emailer/internal/models"
	"github.com/google/uuid"
	"github.com/rs/zerolog"
)

// Sender sends emails via SMTP using account configurations.
type Sender struct {
	accounts map[string]config.AccountConfig
	logger   zerolog.Logger
}

// NewSender creates a new SMTP sender with the given account configs.
func NewSender(accounts []config.AccountConfig, logger zerolog.Logger) *Sender {
	m := make(map[string]config.AccountConfig, len(accounts))
	for _, acct := range accounts {
		m[acct.ID] = acct
	}
	return &Sender{
		accounts: m,
		logger:   logger.With().Str("component", "smtp").Logger(),
	}
}

// Send sends an email for the given account and returns the generated message ID.
func (s *Sender) Send(ctx context.Context, accountID string, compose models.ComposeRequest) (*models.ComposeSendResponse, error) {
	acct, ok := s.accounts[accountID]
	if !ok {
		return nil, fmt.Errorf("unknown account: %s", accountID)
	}

	if acct.SMTP.Host == "" {
		return nil, fmt.Errorf("no SMTP host configured for account %s", accountID)
	}

	messageID := fmt.Sprintf("<%s@%s>", uuid.New().String(), acct.SMTP.Host)
	msg := buildMessage(acct, compose, messageID)

	addr := fmt.Sprintf("%s:%d", acct.SMTP.Host, acct.SMTP.Port)
	auth := smtp.PlainAuth("", acct.Email, acct.AppPassword, acct.SMTP.Host)

	// Collect all recipients.
	recipients := make([]string, 0, len(compose.To)+len(compose.CC)+len(compose.BCC))
	recipients = append(recipients, compose.To...)
	recipients = append(recipients, compose.CC...)
	recipients = append(recipients, compose.BCC...)

	if err := sendMailTLS(ctx, addr, acct.SMTP.Host, auth, acct.Email, recipients, []byte(msg)); err != nil {
		return nil, fmt.Errorf("send email: %w", err)
	}

	s.logger.Info().
		Str("account_id", accountID).
		Str("message_id", messageID).
		Int("recipients", len(recipients)).
		Msg("email sent")

	return &models.ComposeSendResponse{MessageID: messageID}, nil
}

// sendMailTLS connects to an SMTP server using STARTTLS on port 587.
func sendMailTLS(ctx context.Context, addr, host string, auth smtp.Auth, from string, to []string, msg []byte) error {
	dialer := &net.Dialer{Timeout: 10 * time.Second}
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}

	c, err := smtp.NewClient(conn, host)
	if err != nil {
		_ = conn.Close()
		return fmt.Errorf("create SMTP client: %w", err)
	}
	defer func() { _ = c.Close() }()

	// STARTTLS
	tlsConfig := &tls.Config{ServerName: host}
	if err := c.StartTLS(tlsConfig); err != nil {
		return fmt.Errorf("STARTTLS: %w", err)
	}

	if err := c.Auth(auth); err != nil {
		return fmt.Errorf("auth: %w", err)
	}

	if err := c.Mail(from); err != nil {
		return fmt.Errorf("MAIL FROM: %w", err)
	}

	for _, rcpt := range to {
		if err := c.Rcpt(rcpt); err != nil {
			return fmt.Errorf("RCPT TO %s: %w", rcpt, err)
		}
	}

	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("DATA: %w", err)
	}
	if _, err := w.Write(msg); err != nil {
		return fmt.Errorf("write message: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("close data: %w", err)
	}

	return c.Quit()
}

// buildMessage constructs an RFC 2822 email message.
func buildMessage(acct config.AccountConfig, compose models.ComposeRequest, messageID string) string {
	var b strings.Builder

	b.WriteString("From: " + formatAddress(acct.Name, acct.Email) + "\r\n")
	b.WriteString("To: " + strings.Join(compose.To, ", ") + "\r\n")

	if len(compose.CC) > 0 {
		b.WriteString("Cc: " + strings.Join(compose.CC, ", ") + "\r\n")
	}
	// BCC is not included in headers (sent via RCPT TO only).

	b.WriteString("Subject: " + compose.Subject + "\r\n")
	b.WriteString("Date: " + time.Now().UTC().Format(time.RFC1123Z) + "\r\n")
	b.WriteString("Message-ID: " + messageID + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")

	if compose.InReplyTo != "" {
		b.WriteString("In-Reply-To: " + compose.InReplyTo + "\r\n")
		b.WriteString("References: " + compose.InReplyTo + "\r\n")
	}

	if compose.HTMLBody != "" {
		b.WriteString("Content-Type: text/html; charset=UTF-8\r\n")
		b.WriteString("\r\n")
		b.WriteString(compose.HTMLBody)
	} else {
		b.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
		b.WriteString("\r\n")
		b.WriteString(compose.Body)
	}

	return b.String()
}

// formatAddress formats "Name <email>" or just "<email>".
func formatAddress(name, email string) string {
	if name != "" {
		return fmt.Sprintf("%s <%s>", name, email)
	}
	return "<" + email + ">"
}
