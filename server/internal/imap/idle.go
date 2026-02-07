package imap

import (
	"context"
	"fmt"

	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/rs/zerolog"
)

// idleLoop runs a single IDLE session on the given client.
// It blocks until the context is cancelled, the IDLE command reports new data
// via the UnilateralDataHandler (handled externally), or an error occurs.
//
// The go-imap v2 library's Idle() method handles automatic re-issue every 28
// minutes internally, so we don't need to manage that ourselves.
func idleLoop(ctx context.Context, client *imapclient.Client, logger zerolog.Logger) error {
	logger.Debug().Msg("starting IDLE")

	idleCmd, err := client.Idle()
	if err != nil {
		return fmt.Errorf("start IDLE: %w", err)
	}

	// Wait for either context cancellation or IDLE termination.
	doneCh := make(chan error, 1)
	go func() {
		doneCh <- idleCmd.Wait()
	}()

	select {
	case <-ctx.Done():
		// Graceful shutdown: close the IDLE command.
		if closeErr := idleCmd.Close(); closeErr != nil {
			logger.Warn().Err(closeErr).Msg("error closing IDLE command")
		}
		// Wait for the IDLE goroutine to finish.
		<-doneCh
		return ctx.Err()
	case err := <-doneCh:
		// IDLE terminated (server disconnect, error, etc.)
		if err != nil {
			return fmt.Errorf("IDLE: %w", err)
		}
		return nil
	}
}
