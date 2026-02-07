package imap

import (
	"context"
	"fmt"
	"sync"

	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/rs/zerolog"
)

// ConnPool maintains a pool of authenticated IMAP connections for a single account.
// The pool is safe for concurrent use.
type ConnPool struct {
	mu      sync.Mutex
	conns   []*imapclient.Client
	maxSize int
	connect func(ctx context.Context) (*imapclient.Client, error)
	logger  zerolog.Logger
	closed  bool
}

// NewConnPool creates a connection pool with the given max size and connection factory.
func NewConnPool(maxSize int, connect func(ctx context.Context) (*imapclient.Client, error), logger zerolog.Logger) *ConnPool {
	return &ConnPool{
		conns:   make([]*imapclient.Client, 0, maxSize),
		maxSize: maxSize,
		connect: connect,
		logger:  logger.With().Str("component", "pool").Logger(),
	}
}

// Get returns a connection from the pool. If no connections are available,
// it creates a new one. Connections are verified with NOOP before returning.
func (p *ConnPool) Get(ctx context.Context) (*imapclient.Client, error) {
	p.mu.Lock()
	if p.closed {
		p.mu.Unlock()
		return nil, fmt.Errorf("connection pool is closed")
	}

	// Try to return a pooled connection.
	for len(p.conns) > 0 {
		c := p.conns[len(p.conns)-1]
		p.conns = p.conns[:len(p.conns)-1]
		p.mu.Unlock()

		// Verify liveness with NOOP.
		if err := c.Noop().Wait(); err == nil {
			return c, nil
		}
		// Dead connection: close and try the next one.
		p.logger.Debug().Msg("discarding dead pooled connection")
		_ = c.Close()

		p.mu.Lock()
		if p.closed {
			p.mu.Unlock()
			return nil, fmt.Errorf("connection pool is closed")
		}
	}
	p.mu.Unlock()

	// No pooled connections available; create a new one.
	p.logger.Debug().Msg("creating new IMAP connection")
	return p.connect(ctx)
}

// Put returns a connection to the pool. If the pool is full, the connection is closed.
func (p *ConnPool) Put(c *imapclient.Client) {
	if c == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed || len(p.conns) >= p.maxSize {
		_ = c.Close()
		return
	}
	p.conns = append(p.conns, c)
}

// Close closes all connections in the pool and marks it as closed.
func (p *ConnPool) Close() {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.closed = true
	for _, c := range p.conns {
		_ = c.Close()
	}
	p.conns = nil
}

// Size returns the current number of idle connections in the pool.
func (p *ConnPool) Size() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.conns)
}
