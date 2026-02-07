package imap

import (
	"fmt"

	"github.com/emersion/go-sasl"
)

// xoauth2Client implements the XOAUTH2 SASL mechanism used by Gmail and Microsoft.
// See https://developers.google.com/gmail/imap/xoauth2-protocol
type xoauth2Client struct {
	username string
	token    string
}

// NewXOAuth2Client creates a new XOAUTH2 SASL client.
func NewXOAuth2Client(username, token string) sasl.Client {
	return &xoauth2Client{
		username: username,
		token:    token,
	}
}

func (c *xoauth2Client) Start() (mech string, ir []byte, err error) {
	// XOAUTH2 format: "user=" + email + "\x01auth=Bearer " + token + "\x01\x01"
	resp := fmt.Sprintf("user=%s\x01auth=Bearer %s\x01\x01", c.username, c.token)
	return "XOAUTH2", []byte(resp), nil
}

func (c *xoauth2Client) Next(challenge []byte) ([]byte, error) {
	// The server sends a challenge on auth failure.
	// We respond with an empty string to complete the exchange.
	return []byte{}, &AuthError{
		Provider:    "xoauth2",
		Message:     string(challenge),
		Recoverable: false,
	}
}
