package imap

import "fmt"

// Provider constants for supported email providers.
const (
	ProviderGmail     = "gmail"
	ProviderICloud    = "icloud"
	ProviderMicrosoft = "microsoft365"
	ProviderFastmail  = "fastmail"
)

// Auth method constants.
const (
	AuthMethodXOAuth2 = "xoauth2"
	AuthMethodPlain   = "plain"
)

// ProviderConfig holds provider-specific IMAP/SMTP settings and quirks.
type ProviderConfig struct {
	// IMAPHost is the IMAP server hostname.
	IMAPHost string
	// IMAPPort is the IMAP server port (typically 993 for TLS).
	IMAPPort int
	// SMTPHost is the SMTP server hostname.
	SMTPHost string
	// SMTPPort is the SMTP server port (typically 587 for STARTTLS).
	SMTPPort int
	// AuthMethod is the SASL mechanism: "xoauth2", "oauthbearer", or "plain".
	AuthMethod string
	// AutoSaveSent indicates whether the provider auto-saves sent messages.
	AutoSaveSent bool
	// SupportsGmailExtensions indicates Gmail-specific IMAP extensions (labels, thread IDs, etc.).
	SupportsGmailExtensions bool
}

// DefaultProviderConfig returns the default configuration for a known provider.
func DefaultProviderConfig(provider string) (*ProviderConfig, error) {
	switch provider {
	case ProviderGmail:
		return &ProviderConfig{
			IMAPHost:                "imap.gmail.com",
			IMAPPort:                993,
			SMTPHost:                "smtp.gmail.com",
			SMTPPort:                587,
			AuthMethod:              AuthMethodXOAuth2,
			AutoSaveSent:            true,
			SupportsGmailExtensions: true,
		}, nil
	case ProviderICloud:
		return &ProviderConfig{
			IMAPHost:                "imap.mail.me.com",
			IMAPPort:                993,
			SMTPHost:                "smtp.mail.me.com",
			SMTPPort:                587,
			AuthMethod:              AuthMethodPlain,
			AutoSaveSent:            false,
			SupportsGmailExtensions: false,
		}, nil
	case ProviderMicrosoft:
		return &ProviderConfig{
			IMAPHost:                "outlook.office365.com",
			IMAPPort:                993,
			SMTPHost:                "smtp.office365.com",
			SMTPPort:                587,
			AuthMethod:              AuthMethodXOAuth2,
			AutoSaveSent:            false,
			SupportsGmailExtensions: false,
		}, nil
	case ProviderFastmail:
		return &ProviderConfig{
			IMAPHost:                "imap.fastmail.com",
			IMAPPort:                993,
			SMTPHost:                "smtp.fastmail.com",
			SMTPPort:                587,
			AuthMethod:              AuthMethodPlain,
			AutoSaveSent:            false,
			SupportsGmailExtensions: false,
		}, nil
	default:
		return nil, fmt.Errorf("unsupported provider: %s", provider)
	}
}

// IMAPAddress returns the host:port address for IMAP connections.
func (p *ProviderConfig) IMAPAddress() string {
	return fmt.Sprintf("%s:%d", p.IMAPHost, p.IMAPPort)
}
