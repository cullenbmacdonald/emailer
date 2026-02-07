package storage

import (
	"context"
	"testing"
)

func TestIntegrationAddAndListVIPSender(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	vip, err := store.AddVIPSender(ctx, "boss@company.com", "The Boss")
	if err != nil {
		t.Fatalf("AddVIPSender() error: %v", err)
	}
	if vip.ID == "" {
		t.Error("expected generated ID")
	}
	if vip.Email != "boss@company.com" {
		t.Errorf("expected email 'boss@company.com', got %s", vip.Email)
	}

	vips, err := store.ListVIPSenders(ctx)
	if err != nil {
		t.Fatalf("ListVIPSenders() error: %v", err)
	}
	if len(vips) != 1 {
		t.Errorf("expected 1 VIP sender, got %d", len(vips))
	}
}

func TestIntegrationRemoveVIPSender(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	vip, err := store.AddVIPSender(ctx, "remove@example.com", "Remove Me")
	if err != nil {
		t.Fatalf("AddVIPSender: %v", err)
	}

	if err := store.RemoveVIPSender(ctx, vip.ID); err != nil {
		t.Fatalf("RemoveVIPSender() error: %v", err)
	}

	vips, err := store.ListVIPSenders(ctx)
	if err != nil {
		t.Fatalf("ListVIPSenders: %v", err)
	}
	if len(vips) != 0 {
		t.Errorf("expected 0 VIP senders after removal, got %d", len(vips))
	}
}

func TestIntegrationRemoveVIPSenderNotFound(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)

	err := store.RemoveVIPSender(ctx, "00000000-0000-0000-0000-000000000000")
	if err == nil {
		t.Error("expected error for non-existent VIP sender")
	}
}

func TestIntegrationIsVIPSenderExactMatch(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	if _, err := store.AddVIPSender(ctx, "vip@company.com", "VIP Person"); err != nil {
		t.Fatalf("AddVIPSender: %v", err)
	}

	isVIP, err := store.IsVIPSender(ctx, "vip@company.com")
	if err != nil {
		t.Fatalf("IsVIPSender() error: %v", err)
	}
	if !isVIP {
		t.Error("expected exact match to be VIP")
	}

	isVIP, err = store.IsVIPSender(ctx, "notvip@company.com")
	if err != nil {
		t.Fatalf("IsVIPSender() error: %v", err)
	}
	if isVIP {
		t.Error("expected non-match to not be VIP")
	}
}

func TestIntegrationIsVIPSenderDomainMatch(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	// Add domain-level VIP
	if _, err := store.AddVIPSender(ctx, "@important-client.com", "Important Client"); err != nil {
		t.Fatalf("AddVIPSender: %v", err)
	}

	isVIP, err := store.IsVIPSender(ctx, "anyone@important-client.com")
	if err != nil {
		t.Fatalf("IsVIPSender() error: %v", err)
	}
	if !isVIP {
		t.Error("expected domain match to be VIP")
	}

	isVIP, err = store.IsVIPSender(ctx, "someone@other-company.com")
	if err != nil {
		t.Fatalf("IsVIPSender() error: %v", err)
	}
	if isVIP {
		t.Error("expected non-matching domain to not be VIP")
	}
}

func TestIntegrationIsVIPSenderCaseInsensitive(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	if _, err := store.AddVIPSender(ctx, "Boss@Company.com", "Boss"); err != nil {
		t.Fatalf("AddVIPSender: %v", err)
	}

	isVIP, err := store.IsVIPSender(ctx, "boss@company.com")
	if err != nil {
		t.Fatalf("IsVIPSender() error: %v", err)
	}
	if !isVIP {
		t.Error("expected case-insensitive match to be VIP")
	}
}

func TestIntegrationListVIPSendersEmpty(t *testing.T) {
	pool := getTestPool(t)
	ctx := context.Background()

	if err := RunMigrations(ctx, pool); err != nil {
		t.Fatalf("RunMigrations: %v", err)
	}

	store := NewVIPStore(pool)
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, "DELETE FROM vip_senders")
	})

	vips, err := store.ListVIPSenders(ctx)
	if err != nil {
		t.Fatalf("ListVIPSenders() error: %v", err)
	}
	if vips == nil {
		t.Error("expected non-nil slice")
	}
	if len(vips) != 0 {
		t.Errorf("expected 0 VIP senders, got %d", len(vips))
	}
}
