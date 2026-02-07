package imap

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/emersion/go-imap/v2/imapclient"
	"github.com/rs/zerolog"
)

// mockConnFactory returns a factory that creates mock connections.
// It tracks how many connections were created.
type mockConnFactory struct {
	mu          sync.Mutex
	created     int
	shouldError bool
}

func (f *mockConnFactory) connect(ctx context.Context) (*imapclient.Client, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	if f.shouldError {
		return nil, errors.New("connection failed")
	}
	f.created++
	// We can't easily create a real imapclient.Client without a TCP connection,
	// so we'll test the pool logic at a higher level.
	// For unit tests, we test the pool's own logic without actual clients.
	return nil, errors.New("mock: real connections not available in unit tests")
}

func TestConnPool_Close(t *testing.T) {
	factory := &mockConnFactory{}
	pool := NewConnPool(3, factory.connect, zerolog.Nop())

	// Close should not panic on empty pool.
	pool.Close()

	// Subsequent Get should fail.
	_, err := pool.Get(context.Background())
	if err == nil {
		t.Fatal("expected error after pool closed")
	}
}

func TestConnPool_Size(t *testing.T) {
	factory := &mockConnFactory{}
	pool := NewConnPool(3, factory.connect, zerolog.Nop())

	if pool.Size() != 0 {
		t.Errorf("expected initial size 0, got %d", pool.Size())
	}

	pool.Close()
}

func TestConnPool_PutNil(t *testing.T) {
	factory := &mockConnFactory{}
	pool := NewConnPool(3, factory.connect, zerolog.Nop())
	defer pool.Close()

	// Putting nil should not panic.
	pool.Put(nil)
}

func TestConnPool_GetFromClosedPool(t *testing.T) {
	factory := &mockConnFactory{}
	pool := NewConnPool(3, factory.connect, zerolog.Nop())
	pool.Close()

	_, err := pool.Get(context.Background())
	if err == nil {
		t.Fatal("expected error getting from closed pool")
	}
}

func TestConnPool_GetWhenFactoryFails(t *testing.T) {
	factory := &mockConnFactory{shouldError: true}
	pool := NewConnPool(3, factory.connect, zerolog.Nop())
	defer pool.Close()

	_, err := pool.Get(context.Background())
	if err == nil {
		t.Fatal("expected error when factory fails")
	}
}
