# Go Server Architecture Brainstorm

Research notes for the Go server that runs on the Mac Mini hub. This server handles IMAP sync, SMTP sending, AI classification, recommendation extraction, digest generation, and exposes a REST + WebSocket API for native clients.

**Date:** 2026-02-06
**Context:** The previous brainstorms established the hub-and-spoke architecture (Mac Mini as always-on server, clients as thin API consumers), the classification cascade (rules, feature scoring, LLM), SQLite for storage, and Tailscale for remote access. This document covers the Go server implementation in detail.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [IMAP Management](#2-imap-management)
3. [SMTP Sending](#3-smtp-sending)
4. [Storage Layer](#4-storage-layer)
5. [API Design](#5-api-design)
6. [LLM Interface](#6-llm-interface)
7. [Classification Pipeline](#7-classification-pipeline)
8. [Background Jobs](#8-background-jobs)
9. [Configuration](#9-configuration)
10. [Deployment on Mac Mini](#10-deployment-on-mac-mini)
11. [Testing Strategy](#11-testing-strategy)

---

## 1. Project Structure

### Why Go Instead of Swift

The previous brainstorms explored Swift server frameworks (Hummingbird, Vapor). Go is worth reconsidering for the server component because:

- **Single static binary**: `go build` produces one binary with zero runtime dependencies. No Swift runtime, no dynamic libraries, no framework paths to manage. Copy it to the Mac Mini, run it.
- **Goroutines for IMAP**: Each IMAP account needs a persistent IDLE connection plus worker connections. Goroutines handle this naturally with minimal overhead. Managing 6-10 concurrent IMAP connections is trivial.
- **Mature ecosystem for email**: `go-imap` (v2) is actively maintained, well-documented, and purpose-built for both clients and servers. The Go ecosystem for IMAP/SMTP is stronger than Swift's.
- **Cross-compilation**: If the server ever needs to run on Linux (a VPS instead of/alongside the Mac Mini), Go cross-compiles trivially. Swift on Linux is possible but carries more friction.
- **Ollama integration**: Ollama's native API is HTTP/JSON. Go's `net/http` and `encoding/json` make this integration straightforward with no external dependencies.
- **SQLite via CGo**: `mattn/go-sqlite3` is battle-tested. `modernc.org/sqlite` provides a pure-Go alternative if CGo is undesirable.

The trade-off is that the server and the native Swift clients no longer share types. This is acceptable because:
- The API boundary is JSON over HTTP/WebSocket -- types are defined by the API contract, not shared code.
- The data models are simple (enums, strings, timestamps, UUIDs). Keeping Go structs and Swift Codable structs in sync is manageable.
- The server and clients have fundamentally different concerns. Forcing them into one language would compromise one side.

### Recommended Layout

Follow the standard Go project layout conventions. The project uses `cmd/` for executables, `internal/` for private packages, and keeps the module root clean.

```
emailer-server/
    go.mod
    go.sum
    config.example.yaml

    cmd/
        server/
            main.go              # Entry point: wires everything together, starts HTTP server + background jobs

    internal/
        config/
            config.go            # YAML config parsing, env var overrides, validation

        models/
            email.go             # Email, Envelope, Attachment structs
            classification.go    # Classification enum, ClassificationResult
            recommendation.go    # Recommendation, RecommendationType, RecommendationStatus
            account.go           # Account configuration, provider type
            snooze.go            # SnoozeState
            digest.go            # DailyDigest, DigestType
            sync.go              # SyncChange, change feed types

        storage/
            db.go                # SQLite connection setup, WAL mode, pragmas
            migrations.go        # Schema migrations (embed SQL files)
            emails.go            # Email CRUD, queries by queue/date/sender
            classifications.go   # Classification reads/writes
            recommendations.go   # Recommendation CRUD, duplicate detection
            snooze.go            # Snooze state management
            digests.go           # Digest storage
            search.go            # FTS5 full-text search queries
            changes.go           # Change feed (sync_changes table)
            migrations/
                001_initial.sql
                002_add_fts.sql
                ...

        imap/
            manager.go           # AccountManager: starts/stops per-account goroutines
            account.go           # Single account: IDLE connection + worker pool
            idle.go              # IDLE loop with reconnection logic
            fetcher.go           # Fetch envelopes, bodies, structures
            sync.go              # Full sync, incremental sync (CONDSTORE), UID reconciliation
            oauth.go             # OAuth2 token management (Gmail, Microsoft 365)
            provider.go          # Provider-specific config (Gmail extensions, iCloud quirks)

        smtp/
            sender.go            # Per-account SMTP sending
            drafts.go            # Draft storage and sync to IMAP Drafts folder

        classifier/
            pipeline.go          # Orchestrates the classification cascade
            rules.go             # Layer 0: deterministic rules
            features.go          # Layer 1: feature extraction and scoring
            llm.go               # Layer 2/3: LLM-based classification
            feedback.go          # User override processing, training signal collection
            vip.go               # VIP sender list management

        recommender/
            extractor.go         # LLM-based recommendation extraction from newsletters
            dedup.go             # Duplicate detection across recommendations
            types.go             # Extraction prompt templates, JSON schemas

        digest/
            generator.go         # Digest generation logic (template + LLM summaries)
            templates.go         # Morning and evening digest templates
            scheduler.go         # Cron-like scheduling for 6am/7pm

        llm/
            provider.go          # LLMProvider interface definition
            ollama.go            # OllamaProvider: HTTP client for local Ollama
            anthropic.go         # AnthropicProvider: API client
            openai.go            # OpenAIProvider: API client
            structured.go        # JSON mode / structured output helpers

        api/
            server.go            # HTTP server setup, middleware, routing
            routes.go            # Route registration
            auth.go              # Token-based API authentication
            emails.go            # Email list/detail/classify/archive handlers
            search.go            # Search endpoint handler
            snooze.go            # Snooze/unsnooze handlers
            compose.go           # Compose/send/draft handlers
            recommendations.go   # Recommendation list/status handlers
            digests.go           # Digest retrieval handlers
            accounts.go          # Account info handlers
            websocket.go         # WebSocket hub for real-time push
            middleware.go        # Logging, auth, CORS, rate limiting

        jobs/
            scheduler.go         # Background job scheduler (manages all periodic tasks)
            cleanup.go           # Auto-delete filtered items after 14 days
            snooze_return.go     # Process snooze returns (check every minute)
```

### Key Design Principles

**No `pkg/` directory.** The `pkg/` convention is discouraged in modern Go. Everything is in `internal/` (private to this module) since no external code imports our packages.

**`internal/models/` is dependency-free.** Model structs have no imports beyond the standard library. Every other package imports models, but models imports nothing from the project. This prevents circular dependencies.

**One package per concern.** The `imap` package knows nothing about classification. The `classifier` package knows nothing about IMAP. They communicate through models and through the orchestration in `cmd/server/main.go`.

**Interfaces at the consumer.** The `LLMProvider` interface is defined in `internal/llm/provider.go` and consumed by `classifier` and `recommender`. Each consumer accepts the interface, not a concrete type.

---

## 2. IMAP Management

### go-imap v2

The `go-imap` library (github.com/emersion/go-imap) is the standard Go IMAP library. Version 2 is the current release and represents a major rewrite with modern Go idioms.

**Key v2 features:**
- Clean separation between `imapclient` (for connecting to servers) and `imapserver` (for building servers -- we do not need this)
- First-class support for extensions via separate packages: `go-imap-sortthread`, `go-imap-id`, etc.
- Streaming message fetch (does not buffer entire messages in memory)
- Context support for cancellation and timeouts
- Uses `go-message` for MIME parsing (same author, well-integrated)

**Core packages we need:**
```
github.com/emersion/go-imap/v2              # Core IMAP types
github.com/emersion/go-imap/v2/imapclient   # IMAP client
github.com/emersion/go-sasl                  # SASL auth (XOAUTH2, PLAIN)
github.com/emersion/go-message              # MIME parsing
```

### Goroutine-per-Account Architecture

Each email account runs two persistent goroutines plus ephemeral workers:

```
Account (e.g., Gmail personal)
    |
    +-- IDLE goroutine (persistent)
    |       - Maintains one IMAP connection in IDLE on INBOX
    |       - Detects new messages, flag changes, expunges
    |       - Sends events to a channel
    |       - Re-issues IDLE every 14 minutes (before the 29-min RFC timeout)
    |       - Reconnects with exponential backoff on failure
    |
    +-- Worker goroutine (persistent)
    |       - Listens on an event channel
    |       - When IDLE reports new mail: fetches envelopes and bodies
    |       - Runs periodic folder sync (Sent, Drafts, other folders every 5 min)
    |       - Handles on-demand operations (search, flag changes, moves)
    |
    +-- Additional workers (ephemeral, as needed)
            - Spawned for bulk operations (initial sync, large searches)
            - Limited by a per-account semaphore (max 3-4 concurrent connections)
```

**Implementation sketch for the IDLE goroutine:**

```go
func (a *Account) runIDLE(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
        }

        err := a.idleLoop(ctx)
        if err != nil {
            log.Error("IDLE error", "account", a.Name, "error", err)
        }

        // Exponential backoff on reconnect
        select {
        case <-ctx.Done():
            return
        case <-time.After(a.backoff.Next()):
        }
    }
}

func (a *Account) idleLoop(ctx context.Context) error {
    client, err := a.connect(ctx)
    if err != nil {
        return fmt.Errorf("connect: %w", err)
    }
    defer client.Close()

    // SELECT INBOX
    _, err = client.Select("INBOX", nil).Wait()
    if err != nil {
        return fmt.Errorf("select INBOX: %w", err)
    }

    for {
        // Start IDLE with a 14-minute timeout
        idleCmd, err := client.Idle()
        if err != nil {
            return fmt.Errorf("idle start: %w", err)
        }

        // Wait for either a server notification or timeout
        timer := time.NewTimer(14 * time.Minute)
        select {
        case <-ctx.Done():
            timer.Stop()
            idleCmd.Close()
            return ctx.Err()
        case <-timer.C:
            // Re-issue IDLE (keepalive)
            idleCmd.Close()
            continue
        case data := <-client.UnilateralData():
            timer.Stop()
            idleCmd.Close()
            a.handleUnilateral(data)
        }
    }
}
```

### Connection Pooling

Each account maintains a small pool of authenticated IMAP connections for fetch operations. The pool avoids the cost of repeated TCP handshake + TLS + authentication.

```go
type ConnPool struct {
    mu       sync.Mutex
    conns    []*imapclient.Client
    maxSize  int           // 3-4 per account (well within Gmail's 15 limit)
    account  *Account
}

func (p *ConnPool) Get(ctx context.Context) (*imapclient.Client, error) {
    p.mu.Lock()
    if len(p.conns) > 0 {
        c := p.conns[len(p.conns)-1]
        p.conns = p.conns[:len(p.conns)-1]
        p.mu.Unlock()
        // Verify connection is still alive with NOOP
        if err := c.Noop().Wait(); err == nil {
            return c, nil
        }
        c.Close() // Dead connection, create new one
    } else {
        p.mu.Unlock()
    }
    return p.account.connect(ctx)
}

func (p *ConnPool) Put(c *imapclient.Client) {
    p.mu.Lock()
    defer p.mu.Unlock()
    if len(p.conns) < p.maxSize {
        p.conns = append(p.conns, c)
    } else {
        c.Close()
    }
}
```

### OAuth2 Token Management

Gmail and Microsoft 365 require OAuth2 with XOAUTH2 SASL mechanism. iCloud uses app-specific passwords with PLAIN auth.

```go
type OAuthTokenManager struct {
    mu           sync.RWMutex
    accessToken  string
    refreshToken string
    expiry       time.Time
    clientID     string
    clientSecret string
    tokenURL     string
}

func (m *OAuthTokenManager) GetAccessToken(ctx context.Context) (string, error) {
    m.mu.RLock()
    if time.Now().Add(5 * time.Minute).Before(m.expiry) {
        token := m.accessToken
        m.mu.RUnlock()
        return token, nil
    }
    m.mu.RUnlock()

    // Token expired or about to expire, refresh it
    return m.refresh(ctx)
}

func (m *OAuthTokenManager) refresh(ctx context.Context) (string, error) {
    m.mu.Lock()
    defer m.mu.Unlock()

    // Double-check after acquiring write lock
    if time.Now().Add(5 * time.Minute).Before(m.expiry) {
        return m.accessToken, nil
    }

    // POST to token endpoint with refresh_token grant
    resp, err := refreshOAuth2Token(ctx, m.tokenURL, m.clientID, m.clientSecret, m.refreshToken)
    if err != nil {
        return "", fmt.Errorf("oauth2 refresh: %w", err)
    }

    m.accessToken = resp.AccessToken
    m.expiry = time.Now().Add(time.Duration(resp.ExpiresIn) * time.Second)
    if resp.RefreshToken != "" {
        m.refreshToken = resp.RefreshToken // Token rotation
    }

    // Persist new tokens to secure storage
    if err := m.persistTokens(); err != nil {
        log.Error("failed to persist tokens", "error", err)
    }

    return m.accessToken, nil
}
```

**Authentication per provider:**

```go
func (a *Account) authenticate(client *imapclient.Client) error {
    switch a.Provider {
    case ProviderGmail, ProviderMicrosoft365:
        token, err := a.tokenManager.GetAccessToken(context.Background())
        if err != nil {
            return fmt.Errorf("get access token: %w", err)
        }
        saslClient := sasl.NewXOAuth2Client(a.Email, token)
        return client.Authenticate(saslClient).Wait()

    case ProviderICloud:
        saslClient := sasl.NewPlainClient("", a.Email, a.AppPassword)
        return client.Authenticate(saslClient).Wait()

    default:
        return fmt.Errorf("unsupported provider: %s", a.Provider)
    }
}
```

### Reconnection and Error Handling

All IMAP operations use an exponential backoff retry strategy:

```go
type Backoff struct {
    attempt int
    min     time.Duration // 1 second
    max     time.Duration // 5 minutes
}

func (b *Backoff) Next() time.Duration {
    d := b.min * time.Duration(1<<b.attempt)
    if d > b.max {
        d = b.max
    }
    b.attempt++
    return d
}

func (b *Backoff) Reset() {
    b.attempt = 0
}
```

Error categories and handling:

| Error Type | Example | Action |
|---|---|---|
| Authentication failure | `invalid_grant`, wrong password | Pause account, notify user, do not retry automatically |
| Temporary network error | Connection refused, timeout | Retry with exponential backoff |
| Server error | `BYE` response, internal error | Reconnect with backoff |
| UIDVALIDITY change | Mailbox restructured | Invalidate local cache for that folder, full resync |
| Rate limit | Gmail `Too many connections` | Back off 60 seconds, reduce pool size |

### Gmail-Specific Extensions

For Gmail accounts, fetch additional metadata using Gmail IMAP extensions:

- **X-GM-MSGID**: Unique 64-bit message ID, stable across sessions, matches Gmail web URL
- **X-GM-THRID**: Thread/conversation ID for grouping related messages
- **X-GM-LABELS**: All Gmail labels on a message (since Gmail's "folders" are really label views)
- **X-GM-RAW**: Full Gmail search syntax in IMAP SEARCH commands

```go
func (a *Account) fetchGmailExtensions(client *imapclient.Client, uids []imap.UID) error {
    if a.Provider != ProviderGmail {
        return nil
    }
    // Fetch Gmail-specific attributes alongside standard ones
    // X-GM-MSGID and X-GM-THRID are useful for threading and web URL generation
    // X-GM-LABELS gives us the full label set for proper Gmail label display
    fetchCmd := client.Fetch(imap.UIDSet(uids), &imap.FetchOptions{
        // go-imap v2 supports Gmail extensions through the extension mechanism
        // Exact API depends on go-imap-gmail extension package
    })
    // Process results...
    return nil
}
```

For server-side search on Gmail, use X-GM-RAW:

```go
func (a *Account) searchGmail(client *imapclient.Client, query string) ([]imap.UID, error) {
    // X-GM-RAW accepts full Gmail search syntax:
    //   "from:alice has:attachment larger:5M"
    //   "newer_than:7d is:unread"
    //   "label:important -label:read"
    criteria := &imap.SearchCriteria{
        // Use Gmail-specific search via extension
    }
    return client.UIDSearch(criteria).Wait()
}
```

---

## 3. SMTP Sending

### Per-Account Configuration

Each account has its own SMTP settings. The SMTP connection is established on-demand when sending (not persistent like IMAP).

```go
type SMTPConfig struct {
    Host     string // smtp.gmail.com, smtp.mail.me.com, smtp.office365.com
    Port     int    // 587 (STARTTLS) or 465 (implicit TLS)
    AuthType string // "xoauth2" or "plain"
}

func (s *SMTPSender) Send(ctx context.Context, account *Account, msg *ComposeMessage) error {
    // 1. Build the MIME message
    var buf bytes.Buffer
    if err := buildMIMEMessage(&buf, msg); err != nil {
        return fmt.Errorf("build message: %w", err)
    }

    // 2. Connect and authenticate
    client, err := s.connect(ctx, account)
    if err != nil {
        return fmt.Errorf("smtp connect: %w", err)
    }
    defer client.Close()

    // 3. Send
    if err := client.SendMail(msg.From, msg.To, &buf); err != nil {
        return fmt.Errorf("send: %w", err)
    }

    // 4. Save to Sent folder (provider-specific)
    if err := s.saveSentCopy(ctx, account, buf.Bytes()); err != nil {
        log.Error("failed to save sent copy", "error", err)
        // Non-fatal: the email was sent, just the copy failed
    }

    return nil
}
```

### Sent Mail Handling

Gmail auto-saves sent messages to `[Gmail]/Sent Mail` when sent through `smtp.gmail.com`. iCloud and Microsoft 365 do not.

```go
func (s *SMTPSender) saveSentCopy(ctx context.Context, account *Account, raw []byte) error {
    if account.Provider == ProviderGmail {
        return nil // Gmail auto-saves; APPEND would create duplicates
    }

    // APPEND to the Sent folder with \Seen flag
    conn, err := account.pool.Get(ctx)
    if err != nil {
        return err
    }
    defer account.pool.Put(conn)

    sentFolder := account.SpecialFolders.Sent
    appendCmd := conn.Append(sentFolder, int64(len(raw)), nil)
    if _, err := appendCmd.Write(raw); err != nil {
        return err
    }
    return appendCmd.Close()
}
```

### Draft Storage

Drafts are saved to the IMAP Drafts folder so they appear across all devices:

```go
func (s *SMTPSender) SaveDraft(ctx context.Context, account *Account, draft *ComposeMessage) error {
    var buf bytes.Buffer
    if err := buildMIMEMessage(&buf, draft); err != nil {
        return err
    }

    conn, err := account.pool.Get(ctx)
    if err != nil {
        return err
    }
    defer account.pool.Put(conn)

    // If updating an existing draft, delete the old version first
    if draft.PreviousUID > 0 {
        // STORE \Deleted flag on old draft, then EXPUNGE
        storeCmd := conn.Store(imap.UIDSet{draft.PreviousUID},
            &imap.StoreFlags{Op: imap.StoreFlagsAdd, Flags: []imap.Flag{imap.FlagDeleted}}, nil)
        storeCmd.Wait()
        conn.Expunge()
    }

    // APPEND new draft with \Draft flag
    draftsFolder := account.SpecialFolders.Drafts
    flags := []imap.Flag{imap.FlagDraft, imap.FlagSeen}
    appendCmd := conn.Append(draftsFolder, int64(buf.Len()), &imap.AppendOptions{Flags: flags})
    if _, err := appendCmd.Write(buf.Bytes()); err != nil {
        return err
    }
    return appendCmd.Close()
}
```

---

## 4. Storage Layer

### SQLite Setup

Use `mattn/go-sqlite3` (CGo, maximum compatibility and performance) or `modernc.org/sqlite` (pure Go, no CGo dependency). Both support WAL mode and FTS5.

```go
func OpenDB(path string) (*sql.DB, error) {
    db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_busy_timeout=5000&_foreign_keys=ON&_synchronous=NORMAL")
    if err != nil {
        return nil, err
    }

    // Connection pool settings for SQLite
    db.SetMaxOpenConns(1)        // SQLite allows only one writer
    db.SetMaxIdleConns(1)
    db.SetConnMaxLifetime(0)     // Keep connection alive forever

    // Enable WAL mode explicitly (belt and suspenders with the query param)
    if _, err := db.Exec("PRAGMA journal_mode=WAL"); err != nil {
        return nil, fmt.Errorf("enable WAL: %w", err)
    }

    return db, nil
}
```

**Note on concurrent access:** SQLite in WAL mode allows concurrent reads while one writer is active. With `MaxOpenConns(1)`, Go's `database/sql` serializes writes automatically. For read-heavy workloads (API serving email lists), consider a second read-only connection with higher concurrency:

```go
func OpenReadDB(path string) (*sql.DB, error) {
    db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&mode=ro")
    if err != nil {
        return nil, err
    }
    db.SetMaxOpenConns(4) // Multiple concurrent readers are fine
    return db, nil
}
```

### Schema Design

```sql
-- 001_initial.sql

-- Email accounts
CREATE TABLE accounts (
    id          TEXT PRIMARY KEY,     -- UUID
    name        TEXT NOT NULL,        -- "Personal Gmail", "Work", "iCloud"
    email       TEXT NOT NULL UNIQUE,
    provider    TEXT NOT NULL,        -- "gmail", "microsoft365", "icloud"
    account_type TEXT NOT NULL,       -- "work", "personal"
    color       TEXT NOT NULL,        -- Hex color for UI: "#4A90D9"
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Emails (metadata + cached bodies)
CREATE TABLE emails (
    id              TEXT PRIMARY KEY,     -- UUID (our internal ID)
    account_id      TEXT NOT NULL REFERENCES accounts(id),
    message_id      TEXT,                 -- RFC 2822 Message-ID header
    uid             INTEGER,              -- IMAP UID
    folder          TEXT NOT NULL,        -- IMAP folder name
    from_address    TEXT NOT NULL,
    from_name       TEXT,
    to_addresses    TEXT,                 -- JSON array
    cc_addresses    TEXT,                 -- JSON array
    subject         TEXT NOT NULL DEFAULT '',
    snippet         TEXT,                 -- First ~200 chars of body
    text_body       TEXT,                 -- Plain text body (for search + classification)
    html_body       TEXT,                 -- HTML body (for rendering)
    date_received   TEXT NOT NULL,        -- ISO 8601
    date_processed  TEXT,                 -- When we classified it
    has_attachments INTEGER NOT NULL DEFAULT 0,
    raw_headers     TEXT,                 -- Full headers for re-classification
    gmail_msg_id    TEXT,                 -- X-GM-MSGID (Gmail only)
    gmail_thread_id TEXT,                 -- X-GM-THRID (Gmail only)
    gmail_labels    TEXT,                 -- X-GM-LABELS as JSON array (Gmail only)
    is_read         INTEGER NOT NULL DEFAULT 0,
    is_archived     INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_emails_account     ON emails(account_id);
CREATE INDEX idx_emails_date        ON emails(date_received DESC);
CREATE INDEX idx_emails_message_id  ON emails(message_id);
CREATE INDEX idx_emails_from        ON emails(from_address);
CREATE INDEX idx_emails_folder      ON emails(account_id, folder);
CREATE UNIQUE INDEX idx_emails_uid  ON emails(account_id, folder, uid);

-- Classifications
CREATE TABLE classifications (
    id              TEXT PRIMARY KEY,     -- UUID
    email_id        TEXT NOT NULL UNIQUE REFERENCES emails(id),
    classification  TEXT NOT NULL,        -- "action", "newsletter", "filtered", "transactional"
    confidence      REAL NOT NULL,        -- 0.0-1.0
    classified_by   TEXT NOT NULL,        -- "rules", "features", "llm"
    summary         TEXT,                 -- AI-generated one-line summary
    is_overridden   INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_classifications_class ON classifications(classification);
CREATE INDEX idx_classifications_email ON classifications(email_id);

-- User overrides (training signals)
CREATE TABLE overrides (
    id                      TEXT PRIMARY KEY,
    email_id                TEXT NOT NULL REFERENCES emails(id),
    previous_classification TEXT NOT NULL,
    new_classification      TEXT NOT NULL,
    device_id               TEXT,
    overridden_at           TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_overrides_email ON overrides(email_id);

-- Snooze states
CREATE TABLE snoozes (
    id              TEXT PRIMARY KEY,
    email_id        TEXT NOT NULL REFERENCES emails(id),
    snoozed_at      TEXT NOT NULL,
    return_at       TEXT NOT NULL,
    snooze_count    INTEGER NOT NULL DEFAULT 1,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_snoozes_return  ON snoozes(return_at) WHERE is_active = 1;
CREATE INDEX idx_snoozes_email   ON snoozes(email_id);

-- Recommendations extracted from newsletters
CREATE TABLE recommendations (
    id                  TEXT PRIMARY KEY,
    email_id            TEXT NOT NULL REFERENCES emails(id),
    type                TEXT NOT NULL,        -- "book", "movie_tv", "music", "article", "podcast", "other"
    title               TEXT NOT NULL,
    creator             TEXT,                 -- Author, director, artist
    context_snippet     TEXT NOT NULL,        -- The paragraph mentioning the recommendation
    source_name         TEXT NOT NULL,        -- Newsletter name: "Stratechery", "Dense Discovery"
    source_date         TEXT NOT NULL,
    confidence          TEXT NOT NULL,        -- "high", "medium", "low"
    status              TEXT NOT NULL DEFAULT 'new',  -- "new", "saved", "done", "dismissed"
    duplicate_of_id     TEXT REFERENCES recommendations(id),
    duplicate_count     INTEGER NOT NULL DEFAULT 1,
    status_updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
    created_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_recommendations_status ON recommendations(status);
CREATE INDEX idx_recommendations_type   ON recommendations(type);
CREATE INDEX idx_recommendations_email  ON recommendations(email_id);

-- Daily digests
CREATE TABLE digests (
    id              TEXT PRIMARY KEY,
    digest_type     TEXT NOT NULL,        -- "morning", "evening"
    generated_at    TEXT NOT NULL,
    payload         TEXT NOT NULL,        -- JSON blob with full digest content
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_digests_date ON digests(generated_at DESC);

-- VIP senders
CREATE TABLE vip_senders (
    id          TEXT PRIMARY KEY,
    email       TEXT NOT NULL,           -- Can be full address or domain
    name        TEXT,
    added_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX idx_vip_email ON vip_senders(email);

-- Sender statistics (for feature-based classification)
CREATE TABLE sender_stats (
    sender_email    TEXT PRIMARY KEY,
    total_received  INTEGER NOT NULL DEFAULT 0,
    total_replied   INTEGER NOT NULL DEFAULT 0,
    last_received   TEXT,
    last_replied    TEXT,
    avg_reply_time  REAL,                -- Average reply time in hours
    most_common_class TEXT,              -- Most common classification for this sender
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Change feed for client sync
CREATE TABLE sync_changes (
    sequence_number INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp       TEXT NOT NULL DEFAULT (datetime('now')),
    entity_type     TEXT NOT NULL,        -- "email", "classification", "snooze", "recommendation", "digest"
    entity_id       TEXT NOT NULL,
    change_type     TEXT NOT NULL,        -- "created", "updated", "deleted"
    payload         TEXT NOT NULL         -- JSON-encoded entity
);

CREATE INDEX idx_sync_changes_seq ON sync_changes(sequence_number);
```

### FTS5 Full-Text Search

```sql
-- 002_add_fts.sql

-- Full-text search index using external content (avoids duplicating text)
CREATE VIRTUAL TABLE emails_fts USING fts5(
    subject,
    text_body,
    from_name,
    from_address,
    content='emails',
    content_rowid='rowid'
);

-- Triggers to keep FTS index in sync with emails table
CREATE TRIGGER emails_ai AFTER INSERT ON emails BEGIN
    INSERT INTO emails_fts(rowid, subject, text_body, from_name, from_address)
    VALUES (new.rowid, new.subject, new.text_body, new.from_name, new.from_address);
END;

CREATE TRIGGER emails_ad AFTER DELETE ON emails BEGIN
    INSERT INTO emails_fts(emails_fts, rowid, subject, text_body, from_name, from_address)
    VALUES ('delete', old.rowid, old.subject, old.text_body, old.from_name, old.from_address);
END;

CREATE TRIGGER emails_au AFTER UPDATE ON emails BEGIN
    INSERT INTO emails_fts(emails_fts, rowid, subject, text_body, from_name, from_address)
    VALUES ('delete', old.rowid, old.subject, old.text_body, old.from_name, old.from_address);
    INSERT INTO emails_fts(rowid, subject, text_body, from_name, from_address)
    VALUES (new.rowid, new.subject, new.text_body, new.from_name, new.from_address);
END;
```

**Search query in Go:**

```go
func (s *Store) SearchEmails(ctx context.Context, query string, opts SearchOptions) ([]Email, error) {
    sql := `
        SELECT e.*
        FROM emails e
        JOIN emails_fts fts ON e.rowid = fts.rowid
        WHERE emails_fts MATCH ?
    `
    args := []interface{}{query}

    if opts.AccountID != "" {
        sql += " AND e.account_id = ?"
        args = append(args, opts.AccountID)
    }
    if opts.Classification != "" {
        sql += ` AND e.id IN (SELECT email_id FROM classifications WHERE classification = ?)`
        args = append(args, opts.Classification)
    }

    sql += " ORDER BY rank LIMIT ? OFFSET ?"
    args = append(args, opts.Limit, opts.Offset)

    rows, err := s.readDB.QueryContext(ctx, sql, args...)
    // ... scan rows into []Email
}
```

### Migration Strategy

Embed SQL migration files and apply them at startup:

```go
//go:embed migrations/*.sql
var migrationsFS embed.FS

func RunMigrations(db *sql.DB) error {
    // Create migrations tracking table
    db.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    )`)

    // Get current version
    var currentVersion int
    db.QueryRow("SELECT COALESCE(MAX(version), 0) FROM schema_migrations").Scan(&currentVersion)

    // Apply pending migrations
    entries, _ := migrationsFS.ReadDir("migrations")
    for _, entry := range entries {
        version := extractVersion(entry.Name()) // e.g., "001" -> 1
        if version <= currentVersion {
            continue
        }
        content, _ := migrationsFS.ReadFile("migrations/" + entry.Name())
        if _, err := db.Exec(string(content)); err != nil {
            return fmt.Errorf("migration %s: %w", entry.Name(), err)
        }
        db.Exec("INSERT INTO schema_migrations (version) VALUES (?)", version)
        log.Info("applied migration", "file", entry.Name())
    }
    return nil
}
```

---

## 5. API Design

### HTTP Framework

Use the Go standard library `net/http` with Go 1.22+ routing patterns (method + path matching). No external framework needed for this scale. Add `chi` (lightweight router) only if the standard library routing feels limiting.

```go
func NewServer(cfg *config.Config, store *storage.Store, wsHub *WebSocketHub) *http.Server {
    mux := http.NewServeMux()

    // Apply middleware
    handler := chainMiddleware(mux,
        loggingMiddleware,
        corsMiddleware(cfg.API.AllowedOrigins),
        authMiddleware(cfg.API.AuthToken),
    )

    // Register routes
    registerRoutes(mux, store, wsHub)

    return &http.Server{
        Addr:    ":" + cfg.API.Port,
        Handler: handler,
    }
}
```

### API Versioning

Prefix all routes with `/api/v1/`. When breaking changes are needed, introduce `/api/v2/` while keeping v1 alive for a migration period.

### Authentication

For a personal server, a simple bearer token is sufficient. The token is configured in the YAML config and passed in the `Authorization` header.

```go
func authMiddleware(token string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Skip auth for health check
            if r.URL.Path == "/health" {
                next.ServeHTTP(w, r)
                return
            }
            // Skip auth for WebSocket upgrade (auth in WS handshake)
            if r.Header.Get("Upgrade") == "websocket" {
                // Check token in query param for WebSocket
                if r.URL.Query().Get("token") != token {
                    http.Error(w, "unauthorized", http.StatusUnauthorized)
                    return
                }
                next.ServeHTTP(w, r)
                return
            }
            auth := r.Header.Get("Authorization")
            if auth != "Bearer "+token {
                http.Error(w, "unauthorized", http.StatusUnauthorized)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
```

If multi-user is ever needed, replace with JWT tokens and a user table.

### REST Endpoints

```
# Emails
GET    /api/v1/emails                    # List emails with filtering
GET    /api/v1/emails/:id                # Get single email with full body
PATCH  /api/v1/emails/:id                # Update email (mark read, archive)
POST   /api/v1/emails/:id/classify       # Override classification
POST   /api/v1/emails/:id/snooze         # Snooze an email
DELETE /api/v1/emails/:id/snooze         # Cancel snooze

# Search
GET    /api/v1/search?q=...              # Full-text search

# Compose
POST   /api/v1/compose/send              # Send an email
POST   /api/v1/compose/draft             # Save a draft
PUT    /api/v1/compose/draft/:id         # Update a draft
DELETE /api/v1/compose/draft/:id         # Delete a draft

# Recommendations
GET    /api/v1/recommendations            # List recommendations with filtering
PATCH  /api/v1/recommendations/:id       # Update status (save, done, dismiss)

# Digests
GET    /api/v1/digests                   # List recent digests
GET    /api/v1/digests/latest            # Get most recent digest

# Accounts
GET    /api/v1/accounts                  # List accounts with status

# Sync (for clients that want change-feed based sync)
GET    /api/v1/sync/changes?since=N      # Get changes since sequence number N

# VIP
GET    /api/v1/vip                       # List VIP senders
POST   /api/v1/vip                       # Add VIP sender
DELETE /api/v1/vip/:id                   # Remove VIP sender

# Health
GET    /health                            # Server health check (no auth required)
```

### Query Parameters for Email Listing

`GET /api/v1/emails` supports:

| Parameter | Values | Default | Description |
|---|---|---|---|
| `queue` | `action`, `newsletter`, `filtered`, `transactional`, `all` | `all` | Filter by classification queue |
| `account` | account UUID or `all` | `all` | Filter by account |
| `is_read` | `true`, `false` | (no filter) | Filter by read state |
| `sort` | `date`, `sender` | `date` | Sort field |
| `order` | `asc`, `desc` | `desc` | Sort direction |
| `limit` | 1-100 | 50 | Page size |
| `offset` | 0+ | 0 | Pagination offset |
| `snoozed` | `true`, `false` | (no filter) | Filter snoozed items |

**Example responses:**

```json
// GET /api/v1/emails?queue=action&limit=20
{
    "emails": [
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "account_id": "acct-gmail-personal",
            "from_address": "sarah@example.com",
            "from_name": "Sarah Chen",
            "subject": "Can you review the Q1 report?",
            "snippet": "Hey, I just finished the Q1 report and would love your feedback before...",
            "date_received": "2026-02-06T10:30:00Z",
            "is_read": false,
            "has_attachments": true,
            "classification": {
                "classification": "action",
                "confidence": 0.95,
                "classified_by": "features"
            },
            "snooze": null,
            "account_color": "#4A90D9"
        }
    ],
    "total": 12,
    "offset": 0,
    "limit": 20
}
```

```json
// POST /api/v1/emails/550e8400.../snooze
{
    "return_at": "2026-02-07T09:00:00-08:00"
}

// Response
{
    "id": "snooze-uuid",
    "email_id": "550e8400...",
    "return_at": "2026-02-07T17:00:00Z",
    "snooze_count": 2
}
```

### WebSocket for Real-Time Updates

A single WebSocket endpoint pushes events to all connected clients:

```
ws://mac-mini.local:8080/api/v1/ws?token=<auth_token>
```

**Event types pushed to clients:**

```go
type WSEvent struct {
    Type    string          `json:"type"`
    Payload json.RawMessage `json:"payload"`
}

// Event types:
// "email.new"              - New email arrived and classified
// "email.updated"          - Email flags changed (read, archived)
// "classification.changed" - Classification was overridden or updated
// "snooze.returned"        - Snoozed email returned to queue
// "snooze.created"         - Email was snoozed
// "recommendation.new"     - New recommendation extracted
// "digest.generated"       - New digest available
// "account.status"         - Account connection status changed
```

**WebSocket hub implementation:**

```go
type WebSocketHub struct {
    mu      sync.RWMutex
    clients map[*websocket.Conn]bool
}

func (h *WebSocketHub) Broadcast(event WSEvent) {
    data, _ := json.Marshal(event)
    h.mu.RLock()
    defer h.mu.RUnlock()
    for conn := range h.clients {
        conn.WriteMessage(websocket.TextMessage, data)
    }
}

func (h *WebSocketHub) HandleConnection(w http.ResponseWriter, r *http.Request) {
    upgrader := websocket.Upgrader{
        CheckOrigin: func(r *http.Request) bool { return true }, // Auth handled by middleware
    }
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        return
    }

    h.mu.Lock()
    h.clients[conn] = true
    h.mu.Unlock()

    defer func() {
        h.mu.Lock()
        delete(h.clients, conn)
        h.mu.Unlock()
        conn.Close()
    }()

    // Read loop (for client-sent messages, keepalive pongs)
    for {
        _, _, err := conn.ReadMessage()
        if err != nil {
            break
        }
    }
}
```

---

## 6. LLM Interface

### Provider Interface

```go
// internal/llm/provider.go

type LLMProvider interface {
    // Classify returns a classification result for the given email content.
    Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error)

    // ExtractRecommendations extracts structured recommendations from newsletter text.
    ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error)

    // Summarize generates a one-line summary of an email.
    Summarize(ctx context.Context, req SummarizeRequest) (string, error)

    // GenerateDigestNudge generates a smart nudge for a multi-snoozed or borderline item.
    GenerateDigestNudge(ctx context.Context, req NudgeRequest) (string, error)

    // Name returns the provider name for logging.
    Name() string
}

type ClassifyRequest struct {
    Subject     string
    From        string
    To          string   // Was the user in To or CC?
    Body        string   // Truncated to ~2000 tokens
    Headers     map[string]string
}

type ClassifyResponse struct {
    Classification string  // "action", "newsletter", "filtered", "transactional"
    Confidence     float64 // 0.0-1.0
    Reasoning      string  // Brief explanation for debugging
}

type ExtractRequest struct {
    NewsletterName string
    Body           string // Full newsletter text
}

type ExtractResponse struct {
    Recommendations []ExtractedRecommendation
}

type ExtractedRecommendation struct {
    Type       string // "book", "movie_tv", "music", "article", "podcast", "other"
    Title      string
    Creator    string
    Context    string // Quote from newsletter
    Confidence string // "high", "medium", "low"
}
```

### Ollama Provider

Ollama runs locally and exposes an HTTP API on `http://localhost:11434`.

```go
// internal/llm/ollama.go

type OllamaProvider struct {
    baseURL string
    model   string       // e.g., "qwen2.5:7b"
    client  *http.Client
}

func NewOllamaProvider(baseURL, model string) *OllamaProvider {
    return &OllamaProvider{
        baseURL: baseURL,
        model:   model,
        client:  &http.Client{Timeout: 120 * time.Second},
    }
}

func (o *OllamaProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
    prompt := buildClassificationPrompt(req)

    ollamaReq := OllamaChatRequest{
        Model: o.model,
        Messages: []OllamaMessage{
            {Role: "system", Content: classificationSystemPrompt},
            {Role: "user", Content: prompt},
        },
        Format: "json", // Request JSON output
        Options: OllamaOptions{
            Temperature: 0.1, // Low temperature for consistent classification
        },
        Stream: false,
    }

    body, _ := json.Marshal(ollamaReq)
    httpReq, _ := http.NewRequestWithContext(ctx, "POST", o.baseURL+"/api/chat", bytes.NewReader(body))
    httpReq.Header.Set("Content-Type", "application/json")

    resp, err := o.client.Do(httpReq)
    if err != nil {
        return nil, fmt.Errorf("ollama request: %w", err)
    }
    defer resp.Body.Close()

    var ollamaResp OllamaChatResponse
    if err := json.NewDecoder(resp.Body).Decode(&ollamaResp); err != nil {
        return nil, fmt.Errorf("decode response: %w", err)
    }

    // Parse the JSON response from the model
    return parseClassificationJSON(ollamaResp.Message.Content)
}

type OllamaChatRequest struct {
    Model    string          `json:"model"`
    Messages []OllamaMessage `json:"messages"`
    Format   string          `json:"format,omitempty"`
    Options  OllamaOptions   `json:"options,omitempty"`
    Stream   bool            `json:"stream"`
}

type OllamaMessage struct {
    Role    string `json:"role"`
    Content string `json:"content"`
}

type OllamaOptions struct {
    Temperature float64 `json:"temperature,omitempty"`
    NumPredict  int     `json:"num_predict,omitempty"`
}
```

### Anthropic and OpenAI Providers

For a hosted version, implement the same interface against cloud APIs:

```go
// internal/llm/anthropic.go

type AnthropicProvider struct {
    apiKey string
    model  string // e.g., "claude-sonnet-4-20250514"
    client *http.Client
}

func (a *AnthropicProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
    prompt := buildClassificationPrompt(req)

    anthropicReq := map[string]interface{}{
        "model":      a.model,
        "max_tokens": 256,
        "messages": []map[string]string{
            {"role": "user", "content": prompt},
        },
        "system": classificationSystemPrompt,
    }

    body, _ := json.Marshal(anthropicReq)
    httpReq, _ := http.NewRequestWithContext(ctx, "POST", "https://api.anthropic.com/v1/messages", bytes.NewReader(body))
    httpReq.Header.Set("Content-Type", "application/json")
    httpReq.Header.Set("x-api-key", a.apiKey)
    httpReq.Header.Set("anthropic-version", "2023-06-01")

    // ... same pattern as Ollama
}
```

```go
// internal/llm/openai.go

type OpenAIProvider struct {
    apiKey string
    model  string // e.g., "gpt-4o-mini"
    client *http.Client
}

// Same interface implementation, hitting https://api.openai.com/v1/chat/completions
```

### Provider Selection

The active provider is determined by configuration:

```go
func NewLLMProvider(cfg config.LLMConfig) (LLMProvider, error) {
    switch cfg.Provider {
    case "ollama":
        return NewOllamaProvider(cfg.Ollama.BaseURL, cfg.Ollama.Model), nil
    case "anthropic":
        return NewAnthropicProvider(cfg.Anthropic.APIKey, cfg.Anthropic.Model), nil
    case "openai":
        return NewOpenAIProvider(cfg.OpenAI.APIKey, cfg.OpenAI.Model), nil
    default:
        return nil, fmt.Errorf("unknown LLM provider: %s", cfg.Provider)
    }
}
```

### Prompt Design for Classification

```go
const classificationSystemPrompt = `You are an email classifier. Classify each email into exactly one category.

Categories:
- ACTION: The sender expects a response from the recipient. Contains questions, requests, deadlines, or calls to action directed at the reader. When in doubt, choose ACTION.
- NEWSLETTER: Informational content sent to a list. Contains recommendations, news, analysis, or curated links. Not expecting a reply. Has unsubscribe link.
- FILTERED: Unsolicited marketing, promotions, spam, or junk. Promotional language without substantive content.
- TRANSACTIONAL: Automated messages: receipts, shipping notifications, password resets, calendar invites, two-factor codes, order confirmations.

CRITICAL: When uncertain between ACTION and any other category, always choose ACTION. Missing an email that needs a response is far worse than a false positive.

Respond in JSON format:
{
    "classification": "ACTION|NEWSLETTER|FILTERED|TRANSACTIONAL",
    "confidence": 0.0-1.0,
    "reasoning": "brief explanation"
}`

func buildClassificationPrompt(req ClassifyRequest) string {
    return fmt.Sprintf(`Subject: %s
From: %s <%s>
To/CC position: %s
Body (truncated):
%s`,
        req.Subject,
        req.Headers["From"],
        req.From,
        req.To,
        truncate(req.Body, 2000),
    )
}
```

### Prompt Design for Recommendation Extraction

```go
const extractionSystemPrompt = `Extract all recommendations from this newsletter. A recommendation is when the author suggests, endorses, praises, or highlights a specific item.

For each recommendation found, extract:
- type: one of "book", "movie_tv", "music", "article", "podcast", "other"
- title: the name of the recommended item
- creator: author, director, artist, etc. (if mentioned)
- context: the sentence or phrase where the recommendation appears (quote directly from the text)
- confidence: "high" (explicit endorsement), "medium" (positive mention), or "low" (passing reference)

Only include items the author is clearly recommending or endorsing. Do not include items merely mentioned in passing without positive sentiment. Do not include self-promotions or advertisements.

Respond in JSON format:
{
    "recommendations": [
        {
            "type": "book",
            "title": "Example Title",
            "creator": "Author Name",
            "context": "quoted text from newsletter",
            "confidence": "high"
        }
    ]
}`
```

### The Classification Cascade

The LLM is only called as Layer 2/3 of the cascade. Most emails never reach it:

```go
func (p *Pipeline) Classify(ctx context.Context, email *models.Email) (*models.ClassificationResult, error) {
    // Layer 0: Deterministic rules
    if result := p.rules.Classify(email); result != nil {
        return result, nil
    }

    // Layer 1: Feature-based scoring
    result := p.features.Classify(email)
    if result.Confidence >= 0.85 {
        return result, nil
    }

    // Layer 2/3: LLM for uncertain cases
    llmResult, err := p.llmProvider.Classify(ctx, ClassifyRequest{
        Subject: email.Subject,
        From:    email.FromAddress,
        To:      determineRecipientPosition(email),
        Body:    email.TextBody,
        Headers: email.HeaderMap(),
    })
    if err != nil {
        // LLM failed -- fall back to feature result with Action bias
        log.Error("LLM classification failed, using feature result", "error", err)
        if result.Confidence < 0.5 {
            result.Classification = "action" // When truly uncertain, default to Action
        }
        return result, nil
    }

    return &models.ClassificationResult{
        Classification: llmResult.Classification,
        Confidence:     llmResult.Confidence,
        ClassifiedBy:   "llm",
        Summary:        llmResult.Reasoning,
    }, nil
}
```

---

## 7. Classification Pipeline

### Layer 0: Deterministic Rules

```go
// internal/classifier/rules.go

type RuleEngine struct {
    vipSenders    map[string]bool // email -> true
    knownNewsletters map[string]bool // domain -> true
    transactionalPatterns []TransactionalPattern
}

func (r *RuleEngine) Classify(email *models.Email) *models.ClassificationResult {
    // VIP senders always go to Action
    if r.vipSenders[email.FromAddress] {
        return &models.ClassificationResult{
            Classification: "action",
            Confidence:     1.0,
            ClassifiedBy:   "rules",
            Summary:        "VIP sender",
        }
    }

    // No-reply addresses are never Action
    if isNoReply(email.FromAddress) {
        // But they might be transactional or newsletter, continue below
    }

    // Known newsletter domains with List-Unsubscribe header
    if r.knownNewsletters[extractDomain(email.FromAddress)] &&
        email.Headers["List-Unsubscribe"] != "" {
        return &models.ClassificationResult{
            Classification: "newsletter",
            Confidence:     0.99,
            ClassifiedBy:   "rules",
        }
    }

    // Transactional patterns (subject line matching)
    for _, pattern := range r.transactionalPatterns {
        if pattern.Match(email) {
            return &models.ClassificationResult{
                Classification: "transactional",
                Confidence:     0.95,
                ClassifiedBy:   "rules",
            }
        }
    }

    // Precedence: bulk header -> not action
    if email.Headers["Precedence"] == "bulk" || email.Headers["Precedence"] == "list" {
        // This is mass mail, skip to features for newsletter vs filtered
        return nil // Let Layer 1 handle
    }

    return nil // Uncertain, pass to Layer 1
}

func isNoReply(addr string) bool {
    lower := strings.ToLower(addr)
    return strings.HasPrefix(lower, "noreply@") ||
        strings.HasPrefix(lower, "no-reply@") ||
        strings.HasPrefix(lower, "donotreply@") ||
        strings.HasPrefix(lower, "do-not-reply@") ||
        strings.Contains(lower, "mailer-daemon")
}

type TransactionalPattern struct {
    SubjectContains []string // Any match triggers
    FromContains    []string
}

var defaultTransactionalPatterns = []TransactionalPattern{
    {SubjectContains: []string{"your order", "order confirmation", "order shipped"}},
    {SubjectContains: []string{"shipping confirmation", "delivery notification", "out for delivery"}},
    {SubjectContains: []string{"your receipt", "payment received", "payment confirmation"}},
    {SubjectContains: []string{"password reset", "reset your password", "verify your email"}},
    {SubjectContains: []string{"verification code", "security code", "one-time code"}},
    {SubjectContains: []string{"calendar invitation", "event invitation"}},
    {FromContains: []string{"noreply@github.com", "notifications@github.com"}},
}
```

### Layer 1: Feature-Based Scoring

```go
// internal/classifier/features.go

type FeatureClassifier struct {
    store *storage.Store
}

type FeatureVector struct {
    // Header features
    HasListUnsubscribe bool
    IsInToField        bool    // vs CC/BCC
    RecipientCount     int
    HasBulkHeaders     bool
    ReplyToDiffersFrom bool

    // Sender behavior (from sender_stats table)
    SenderReplyRate    float64 // 0.0-1.0: how often user replies to this sender
    SenderFrequency    float64 // Emails per week from this sender
    DaysSinceLastReply float64
    SenderInContacts   bool
    SenderPriorClass   string  // Most common prior classification

    // Content features
    QuestionMarkCount  int
    HasActionPhrases   bool    // "can you", "could you", "let me know", etc.
    HasDeadlineMention bool    // Dates within 7 days
    BodyLength         int
    LinkCount          int
    ImageCount         int
    HasUnsubscribeText bool    // "unsubscribe" in body text
    PromoWordDensity   float64 // Density of "sale", "offer", "limited time", etc.
    HTMLComplexity     float64 // Ratio of HTML tags to text content
}

func (f *FeatureClassifier) ExtractFeatures(email *models.Email) FeatureVector {
    vec := FeatureVector{
        HasListUnsubscribe: email.Headers["List-Unsubscribe"] != "",
        IsInToField:        isDirectRecipient(email),
        RecipientCount:     countRecipients(email),
        HasBulkHeaders:     hasBulkHeaders(email),
        BodyLength:         len(email.TextBody),
        LinkCount:          countLinks(email.TextBody),
        QuestionMarkCount:  countDirectedQuestions(email.TextBody),
        HasActionPhrases:   hasActionPhrases(email.TextBody),
        HasDeadlineMention: hasNearDeadline(email.TextBody),
        HasUnsubscribeText: strings.Contains(strings.ToLower(email.TextBody), "unsubscribe"),
    }

    // Fetch sender history from database
    stats, err := f.store.GetSenderStats(email.FromAddress)
    if err == nil && stats != nil {
        vec.SenderReplyRate = float64(stats.TotalReplied) / float64(max(stats.TotalReceived, 1))
        vec.SenderPriorClass = stats.MostCommonClass
    }

    return vec
}

func (f *FeatureClassifier) Classify(email *models.Email) *models.ClassificationResult {
    vec := f.ExtractFeatures(email)

    // Score each class
    scores := map[string]float64{
        "action":        f.scoreAction(vec),
        "newsletter":    f.scoreNewsletter(vec),
        "filtered":      f.scoreFiltered(vec),
        "transactional": f.scoreTransactional(vec),
    }

    // Apply Action bias: boost Action score by 20%
    scores["action"] *= 1.2

    // Find the winner
    bestClass := "action" // Default to action
    bestScore := 0.0
    totalScore := 0.0
    for class, score := range scores {
        totalScore += score
        if score > bestScore {
            bestScore = score
            bestClass = class
        }
    }

    confidence := bestScore / totalScore // Normalize to 0-1

    return &models.ClassificationResult{
        Classification: bestClass,
        Confidence:     confidence,
        ClassifiedBy:   "features",
    }
}

func (f *FeatureClassifier) scoreAction(v FeatureVector) float64 {
    score := 0.0
    if v.IsInToField            { score += 2.0 }
    if v.QuestionMarkCount > 0  { score += float64(min(v.QuestionMarkCount, 3)) * 1.5 }
    if v.HasActionPhrases       { score += 3.0 }
    if v.HasDeadlineMention     { score += 2.5 }
    if v.SenderReplyRate > 0.3  { score += 2.0 }
    if v.RecipientCount <= 3    { score += 1.0 }
    if v.BodyLength < 500       { score += 0.5 } // Short personal emails
    return score
}

func (f *FeatureClassifier) scoreNewsletter(v FeatureVector) float64 {
    score := 0.0
    if v.HasListUnsubscribe     { score += 3.0 }
    if v.HasBulkHeaders         { score += 2.0 }
    if v.LinkCount > 5          { score += 1.5 }
    if v.HasUnsubscribeText     { score += 1.0 }
    if v.BodyLength > 2000      { score += 1.0 }
    if v.HTMLComplexity > 0.3   { score += 1.0 }
    if v.SenderPriorClass == "newsletter" { score += 2.5 }
    return score
}

func (f *FeatureClassifier) scoreFiltered(v FeatureVector) float64 {
    score := 0.0
    if v.PromoWordDensity > 0.05 { score += 2.0 }
    if !v.IsInToField && v.RecipientCount > 10 { score += 1.5 }
    if v.SenderPriorClass == "filtered" { score += 3.0 }
    if v.ReplyToDiffersFrom     { score += 1.0 }
    return score
}

func (f *FeatureClassifier) scoreTransactional(v FeatureVector) float64 {
    score := 0.0
    if v.SenderPriorClass == "transactional" { score += 3.0 }
    // Most transactional is caught by Layer 0 rules
    return score
}
```

### Confidence Thresholds and Action Bias

The pipeline enforces the "aggressive for Action Queue" bias at every stage:

| Scenario | Behavior |
|---|---|
| Layer 1 confidence >= 0.85 | Accept the classification |
| Layer 1 says Action with confidence >= 0.6 | Accept as Action (lower threshold for Action) |
| Layer 1 uncertain, Layer 2 LLM says Action with confidence >= 0.5 | Accept as Action |
| Layer 2 LLM says non-Action with confidence < 0.8 | Override to Action (need high confidence to exclude from Action) |
| LLM fails / unavailable | Default to Action if Layer 1 confidence < 0.5 |
| New/unknown sender with any ambiguity | Default to Action |

### User Feedback Loop

```go
// internal/classifier/feedback.go

func (f *FeedbackProcessor) ProcessOverride(ctx context.Context, emailID string, newClass string) error {
    email, _ := f.store.GetEmail(ctx, emailID)
    existing, _ := f.store.GetClassification(ctx, emailID)

    // Record the override
    override := &models.Override{
        EmailID:               emailID,
        PreviousClassification: existing.Classification,
        NewClassification:     newClass,
    }
    f.store.SaveOverride(ctx, override)

    // Update the classification
    existing.Classification = newClass
    existing.IsOverridden = true
    f.store.UpdateClassification(ctx, existing)

    // Update sender stats (training signal)
    f.store.IncrementSenderClass(ctx, email.FromAddress, newClass)

    // If moved FROM filtered TO action, this is a critical false negative
    if existing.Classification == "filtered" && newClass == "action" {
        log.Warn("false negative detected",
            "email_id", emailID,
            "from", email.FromAddress,
            "subject", email.Subject)
    }

    // Broadcast the change to connected clients
    f.wsHub.Broadcast(WSEvent{
        Type: "classification.changed",
        Payload: marshal(existing),
    })

    return nil
}
```

---

## 8. Background Jobs

### Job Scheduler

A simple scheduler that runs periodic tasks using goroutines and tickers:

```go
// internal/jobs/scheduler.go

type Scheduler struct {
    store    *storage.Store
    wsHub    *api.WebSocketHub
    llm      llm.LLMProvider
    imapMgr  *imap.Manager
    pipeline *classifier.Pipeline
    extract  *recommender.Extractor
    digest   *digest.Generator

    ctx    context.Context
    cancel context.CancelFunc
    wg     sync.WaitGroup
}

func (s *Scheduler) Start() {
    // IMAP sync is managed by the IMAP manager (goroutine-per-account)
    s.imapMgr.Start(s.ctx)

    // Classification pipeline: triggered by IMAP manager when new emails arrive
    s.wg.Add(1)
    go s.runClassificationWorker()

    // Digest generation: 6am and 7pm
    s.wg.Add(1)
    go s.runDigestScheduler()

    // Snooze return check: every minute
    s.wg.Add(1)
    go s.runSnoozeChecker()

    // Auto-cleanup: once per hour
    s.wg.Add(1)
    go s.runCleanup()

    // Recommendation extraction: triggered after newsletter classification
    s.wg.Add(1)
    go s.runRecommendationWorker()
}
```

### Classification on New Emails

The IMAP manager sends new emails to a channel. A worker goroutine processes them:

```go
func (s *Scheduler) runClassificationWorker() {
    defer s.wg.Done()
    for {
        select {
        case <-s.ctx.Done():
            return
        case email := <-s.imapMgr.NewEmails():
            result, err := s.pipeline.Classify(s.ctx, email)
            if err != nil {
                log.Error("classification failed", "email_id", email.ID, "error", err)
                continue
            }

            s.store.SaveClassification(s.ctx, email.ID, result)

            // Broadcast to connected clients
            s.wsHub.Broadcast(WSEvent{
                Type: "email.new",
                Payload: marshal(EmailWithClassification{Email: email, Classification: result}),
            })

            // If newsletter, queue for recommendation extraction
            if result.Classification == "newsletter" {
                s.newsletterQueue <- email
            }
        }
    }
}
```

### Digest Generation

```go
func (s *Scheduler) runDigestScheduler() {
    defer s.wg.Done()
    for {
        now := time.Now()
        nextDigest := nextDigestTime(now) // Returns 6am or 7pm, whichever is next
        timer := time.NewTimer(time.Until(nextDigest))

        select {
        case <-s.ctx.Done():
            timer.Stop()
            return
        case t := <-timer.C:
            digestType := "morning"
            if t.Hour() >= 12 {
                digestType = "evening"
            }

            digest, err := s.digest.Generate(s.ctx, digestType)
            if err != nil {
                log.Error("digest generation failed", "type", digestType, "error", err)
                continue
            }

            s.store.SaveDigest(s.ctx, digest)
            s.wsHub.Broadcast(WSEvent{
                Type:    "digest.generated",
                Payload: marshal(digest),
            })
        }
    }
}

func nextDigestTime(now time.Time) time.Time {
    today6am := time.Date(now.Year(), now.Month(), now.Day(), 6, 0, 0, 0, now.Location())
    today7pm := time.Date(now.Year(), now.Month(), now.Day(), 19, 0, 0, 0, now.Location())

    if now.Before(today6am) {
        return today6am
    }
    if now.Before(today7pm) {
        return today7pm
    }
    // Next day 6am
    return today6am.Add(24 * time.Hour)
}
```

### Snooze Return Processing

```go
func (s *Scheduler) runSnoozeChecker() {
    defer s.wg.Done()
    ticker := time.NewTicker(1 * time.Minute)
    defer ticker.Stop()

    for {
        select {
        case <-s.ctx.Done():
            return
        case <-ticker.C:
            returned, err := s.store.GetReturnedSnoozes(s.ctx, time.Now())
            if err != nil {
                log.Error("snooze check failed", "error", err)
                continue
            }

            for _, snooze := range returned {
                snooze.IsActive = false
                s.store.UpdateSnooze(s.ctx, snooze)

                s.wsHub.Broadcast(WSEvent{
                    Type:    "snooze.returned",
                    Payload: marshal(snooze),
                })
            }
        }
    }
}
```

### Auto-Deletion of Filtered Items

```go
func (s *Scheduler) runCleanup() {
    defer s.wg.Done()
    ticker := time.NewTicker(1 * time.Hour)
    defer ticker.Stop()

    for {
        select {
        case <-s.ctx.Done():
            return
        case <-ticker.C:
            cutoff := time.Now().Add(-14 * 24 * time.Hour) // 14 days ago
            count, err := s.store.DeleteFilteredBefore(s.ctx, cutoff)
            if err != nil {
                log.Error("cleanup failed", "error", err)
                continue
            }
            if count > 0 {
                log.Info("cleaned up filtered emails", "count", count)
            }
        }
    }
}
```

### Recommendation Extraction from Newsletters

```go
func (s *Scheduler) runRecommendationWorker() {
    defer s.wg.Done()
    for {
        select {
        case <-s.ctx.Done():
            return
        case email := <-s.newsletterQueue:
            recs, err := s.extract.Extract(s.ctx, email)
            if err != nil {
                log.Error("recommendation extraction failed", "email_id", email.ID, "error", err)
                continue
            }

            for _, rec := range recs {
                // Check for duplicates
                existing, _ := s.store.FindSimilarRecommendation(s.ctx, rec.Title, rec.Type)
                if existing != nil {
                    // Merge: increment duplicate count, add source
                    existing.DuplicateCount++
                    s.store.UpdateRecommendation(s.ctx, existing)
                } else {
                    s.store.SaveRecommendation(s.ctx, &rec)
                    s.wsHub.Broadcast(WSEvent{
                        Type:    "recommendation.new",
                        Payload: marshal(rec),
                    })
                }
            }
        }
    }
}
```

---

## 9. Configuration

### YAML Config File

```yaml
# config.yaml

server:
  port: "8080"
  auth_token: "your-secret-token-here"  # For API authentication

database:
  path: "/Users/cullen/Library/Application Support/emailer/emailer.db"

accounts:
  - id: "personal-gmail"
    name: "Personal Gmail"
    email: "cullen@gmail.com"
    provider: "gmail"
    type: "personal"
    color: "#34A853"
    imap:
      host: "imap.gmail.com"
      port: 993
    smtp:
      host: "smtp.gmail.com"
      port: 587
    oauth:
      client_id: "your-client-id.apps.googleusercontent.com"
      client_secret: "your-client-secret"
      token_file: "/Users/cullen/.config/emailer/gmail-token.json"

  - id: "personal-icloud"
    name: "Personal iCloud"
    email: "cullen@icloud.com"
    provider: "icloud"
    type: "personal"
    color: "#FF9500"
    imap:
      host: "imap.mail.me.com"
      port: 993
    smtp:
      host: "smtp.mail.me.com"
      port: 587
    # app_password stored in keychain or encrypted config (see below)

  - id: "work-microsoft"
    name: "Work"
    email: "cullen@company.com"
    provider: "microsoft365"
    type: "work"
    color: "#4A90D9"
    imap:
      host: "outlook.office365.com"
      port: 993
    smtp:
      host: "smtp.office365.com"
      port: 587
    oauth:
      client_id: "your-azure-app-id"
      tenant_id: "your-tenant-id"
      token_file: "/Users/cullen/.config/emailer/microsoft-token.json"

llm:
  provider: "ollama"    # "ollama", "anthropic", "openai"
  ollama:
    base_url: "http://localhost:11434"
    model: "qwen2.5:7b"
  anthropic:
    api_key: ""          # Set via EMAILER_ANTHROPIC_API_KEY env var
    model: "claude-sonnet-4-20250514"
  openai:
    api_key: ""          # Set via EMAILER_OPENAI_API_KEY env var
    model: "gpt-4o-mini"

classification:
  action_confidence_threshold: 0.6     # Lower threshold for Action (aggressive)
  general_confidence_threshold: 0.85   # Threshold for other classes
  llm_fallback_threshold: 0.85        # Below this, escalate to LLM

digest:
  morning_time: "06:00"
  evening_time: "19:00"
  timezone: "America/Los_Angeles"

cleanup:
  filtered_retention_days: 14

sync:
  imap_idle_restart_minutes: 14
  folder_poll_minutes: 5
  full_resync_minutes: 30

logging:
  level: "info"    # "debug", "info", "warn", "error"
  file: "/Users/cullen/Library/Logs/emailer/server.log"
```

### Environment Variable Overrides

```go
func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var cfg Config
    if err := yaml.Unmarshal(data, &cfg); err != nil {
        return nil, err
    }

    // Environment variable overrides (higher priority than config file)
    if v := os.Getenv("EMAILER_PORT"); v != "" {
        cfg.Server.Port = v
    }
    if v := os.Getenv("EMAILER_AUTH_TOKEN"); v != "" {
        cfg.Server.AuthToken = v
    }
    if v := os.Getenv("EMAILER_ANTHROPIC_API_KEY"); v != "" {
        cfg.LLM.Anthropic.APIKey = v
    }
    if v := os.Getenv("EMAILER_OPENAI_API_KEY"); v != "" {
        cfg.LLM.OpenAI.APIKey = v
    }
    if v := os.Getenv("EMAILER_LLM_PROVIDER"); v != "" {
        cfg.LLM.Provider = v
    }
    if v := os.Getenv("EMAILER_DB_PATH"); v != "" {
        cfg.Database.Path = v
    }

    return &cfg, nil
}
```

### Credential Storage

For macOS, use the Keychain via the `go-keyring` package for storing sensitive credentials (app passwords, OAuth tokens):

```go
import "github.com/zalando/go-keyring"

const serviceName = "com.cullen.emailer"

func StoreCredential(accountID, secret string) error {
    return keyring.Set(serviceName, accountID, secret)
}

func GetCredential(accountID string) (string, error) {
    return keyring.Get(serviceName, accountID)
}
```

If running headless (no GUI Keychain access), fall back to an encrypted config file:

```go
// Encrypt secrets with a master key derived from a passphrase
// stored in an environment variable or entered at startup
func encryptSecret(plaintext, key []byte) ([]byte, error) {
    block, _ := aes.NewCipher(key)
    gcm, _ := cipher.NewGCM(block)
    nonce := make([]byte, gcm.NonceSize())
    io.ReadFull(rand.Reader, nonce)
    return gcm.Seal(nonce, nonce, plaintext, nil), nil
}
```

---

## 10. Deployment on Mac Mini

### launchd plist

Create a Launch Agent so the server starts at login and restarts on crash:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cullen.emailer-server</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/emailer-server</string>
        <string>--config</string>
        <string>/Users/cullen/.config/emailer/config.yaml</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/Users/cullen/Library/Logs/emailer/stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/cullen/Library/Logs/emailer/stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>EMAILER_AUTH_TOKEN</key>
        <string>your-token</string>
    </dict>

    <key>ProcessType</key>
    <string>Background</string>

    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
```

Install and manage:

```bash
# Install
cp com.cullen.emailer-server.plist ~/Library/LaunchAgents/

# Load (start)
launchctl load ~/Library/LaunchAgents/com.cullen.emailer-server.plist

# Unload (stop)
launchctl unload ~/Library/LaunchAgents/com.cullen.emailer-server.plist

# Check status
launchctl list | grep emailer
```

### Logging Strategy

Use Go's `log/slog` (standard library structured logging, Go 1.21+):

```go
func setupLogging(cfg config.LoggingConfig) {
    var handler slog.Handler

    // File output with rotation
    logFile, _ := os.OpenFile(cfg.File, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)

    level := slog.LevelInfo
    switch cfg.Level {
    case "debug":
        level = slog.LevelDebug
    case "warn":
        level = slog.LevelWarn
    case "error":
        level = slog.LevelError
    }

    handler = slog.NewJSONHandler(logFile, &slog.HandlerOptions{Level: level})
    slog.SetDefault(slog.New(handler))
}
```

Log rotation: use `lumberjack` for automatic log rotation, or rely on macOS `newsyslog` configured via `/etc/newsyslog.d/`.

### Health Check Endpoint

```go
// GET /health (no auth required)
func healthHandler(store *storage.Store, imapMgr *imap.Manager) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        health := map[string]interface{}{
            "status":    "ok",
            "timestamp": time.Now().UTC().Format(time.RFC3339),
            "uptime":    time.Since(startTime).String(),
            "accounts":  imapMgr.AccountStatuses(),
            "database":  store.Ping() == nil,
        }

        // Check if any account is disconnected
        for _, status := range imapMgr.AccountStatuses() {
            if !status.Connected {
                health["status"] = "degraded"
            }
        }

        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(health)
    }
}
```

**Example response:**

```json
{
    "status": "ok",
    "timestamp": "2026-02-06T15:30:00Z",
    "uptime": "72h15m30s",
    "accounts": [
        {"id": "personal-gmail", "connected": true, "last_sync": "2026-02-06T15:29:45Z"},
        {"id": "personal-icloud", "connected": true, "last_sync": "2026-02-06T15:28:12Z"},
        {"id": "work-microsoft", "connected": true, "last_sync": "2026-02-06T15:29:50Z"}
    ],
    "database": true
}
```

### Tailscale for Remote Access

Tailscale creates a private WireGuard mesh network. The Mac Mini gets a stable Tailscale IP (e.g., `100.64.x.x`) accessible from any device on the tailnet.

**Setup:**
1. Install Tailscale on the Mac Mini: `brew install tailscale`
2. Start and authenticate: `sudo tailscale up`
3. Install Tailscale on iOS/macOS client devices
4. All devices join the same tailnet

The server binds to `0.0.0.0:8080`. Clients connect to:
- Local: `http://mac-mini.local:8080` (Bonjour/mDNS)
- Remote: `http://100.64.x.x:8080` (Tailscale IP)
- Or use Tailscale MagicDNS: `http://mac-mini.tailnet-name.ts.net:8080`

No port forwarding, no public exposure, all traffic encrypted.

### Ollama as a Companion Service

Ollama runs as a separate process on the Mac Mini. Install and configure:

```bash
# Install
brew install ollama

# Pull the model
ollama pull qwen2.5:7b

# Ollama runs as a macOS service automatically after install
# Verify it's running
curl http://localhost:11434/api/tags
```

Ollama starts automatically via its own Launch Agent. The emailer server connects to it over localhost. If Ollama is not running, the classification pipeline falls back to Layer 0 (rules) and Layer 1 (features) only, logging a warning.

---

## 11. Testing Strategy

### Unit Tests for Classification Rules

```go
// internal/classifier/rules_test.go

func TestRuleEngine_VIPSender(t *testing.T) {
    engine := NewRuleEngine([]string{"boss@company.com"}, nil, nil)
    email := &models.Email{
        FromAddress: "boss@company.com",
        Subject:     "Quick question",
    }
    result := engine.Classify(email)
    assert.NotNil(t, result)
    assert.Equal(t, "action", result.Classification)
    assert.Equal(t, 1.0, result.Confidence)
}

func TestRuleEngine_TransactionalPattern(t *testing.T) {
    engine := NewRuleEngine(nil, nil, defaultTransactionalPatterns)
    tests := []struct {
        subject  string
        expected string
    }{
        {"Your order has shipped", "transactional"},
        {"Your receipt from Apple", "transactional"},
        {"Reset your password", "transactional"},
        {"Verification code: 123456", "transactional"},
    }
    for _, tt := range tests {
        email := &models.Email{Subject: tt.subject, FromAddress: "noreply@example.com"}
        result := engine.Classify(email)
        assert.NotNil(t, result, "subject: %s", tt.subject)
        assert.Equal(t, tt.expected, result.Classification, "subject: %s", tt.subject)
    }
}

func TestRuleEngine_NewsletterWithListUnsubscribe(t *testing.T) {
    engine := NewRuleEngine(nil, []string{"substack.com"}, nil)
    email := &models.Email{
        FromAddress: "newsletter@substack.com",
        Headers:     map[string]string{"List-Unsubscribe": "<mailto:unsub@substack.com>"},
    }
    result := engine.Classify(email)
    assert.NotNil(t, result)
    assert.Equal(t, "newsletter", result.Classification)
}

func TestRuleEngine_AmbiguousEmail_ReturnsNil(t *testing.T) {
    engine := NewRuleEngine(nil, nil, nil)
    email := &models.Email{
        FromAddress: "colleague@other.com",
        Subject:     "Thoughts on the proposal",
    }
    result := engine.Classify(email)
    assert.Nil(t, result) // Should pass to Layer 1
}
```

### Unit Tests for Feature Scoring

```go
// internal/classifier/features_test.go

func TestFeatureClassifier_DirectQuestion(t *testing.T) {
    store := newMockStore()
    fc := NewFeatureClassifier(store)

    email := &models.Email{
        FromAddress: "alice@example.com",
        Subject:     "Can you review this by Friday?",
        TextBody:    "Hey, can you take a look at the attached report? I need your feedback by end of day Friday.",
        ToAddresses: []string{"cullen@gmail.com"},
    }

    result := fc.Classify(email)
    assert.Equal(t, "action", result.Classification)
    assert.True(t, result.Confidence > 0.7)
}

func TestFeatureClassifier_MarketingEmail(t *testing.T) {
    store := newMockStore()
    store.AddSenderStat("promo@store.com", &SenderStats{
        TotalReceived:  50,
        TotalReplied:   0,
        MostCommonClass: "filtered",
    })
    fc := NewFeatureClassifier(store)

    email := &models.Email{
        FromAddress: "promo@store.com",
        Subject:     "Flash Sale! 50% off everything!",
        TextBody:    "Limited time offer! Click here to save big. Unsubscribe here.",
        CCAddresses: []string{"cullen@gmail.com"}, // CC, not To
    }

    result := fc.Classify(email)
    assert.Equal(t, "filtered", result.Classification)
}
```

### Mock LLM Provider for Testing

```go
// internal/llm/mock.go

type MockLLMProvider struct {
    ClassifyFunc             func(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error)
    ExtractRecommendationsFunc func(ctx context.Context, req ExtractRequest) (*ExtractResponse, error)
}

func (m *MockLLMProvider) Classify(ctx context.Context, req ClassifyRequest) (*ClassifyResponse, error) {
    if m.ClassifyFunc != nil {
        return m.ClassifyFunc(ctx, req)
    }
    return &ClassifyResponse{
        Classification: "action",
        Confidence:     0.8,
        Reasoning:      "mock classification",
    }, nil
}

func (m *MockLLMProvider) ExtractRecommendations(ctx context.Context, req ExtractRequest) (*ExtractResponse, error) {
    if m.ExtractRecommendationsFunc != nil {
        return m.ExtractRecommendationsFunc(ctx, req)
    }
    return &ExtractResponse{Recommendations: nil}, nil
}

func (m *MockLLMProvider) Name() string { return "mock" }
```

### Integration Tests with a Local IMAP Server

Use `go-imap/v2/imapserver` to spin up a test IMAP server, or use a Docker container with a real IMAP server:

```go
// internal/imap/integration_test.go

func TestIMAPSync_FetchNewMessages(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    // Option A: Use testcontainers-go to spin up a Greenmail or Dovecot container
    // Option B: Use go-imap's imapserver for an in-memory test server

    // Start test IMAP server
    server := newTestIMAPServer(t)
    defer server.Close()

    // Inject test messages
    server.DeliverMessage("INBOX", testMessage{
        From:    "test@example.com",
        Subject: "Test message",
        Body:    "Hello, this is a test.",
    })

    // Create account pointed at test server
    account := &Account{
        Email:    "user@test.local",
        Provider: ProviderGeneric,
        IMAP:     IMAPConfig{Host: "localhost", Port: server.Port()},
    }

    // Run sync
    syncer := NewSyncer(account, testStore(t))
    emails, err := syncer.SyncInbox(context.Background())

    assert.NoError(t, err)
    assert.Len(t, emails, 1)
    assert.Equal(t, "Test message", emails[0].Subject)
}
```

### Test Fixtures for Email Parsing

Store real-world email samples (anonymized) as test fixtures:

```
internal/
    testdata/
        emails/
            simple_text.eml          # Plain text personal email
            html_newsletter.eml      # Rich HTML newsletter with images
            multipart_attachment.eml  # Email with PDF attachment
            gmail_labels.eml         # Gmail email with X-GM-LABELS
            broken_encoding.eml      # Email with charset issues
            action_question.eml      # Email with direct question
            transactional_receipt.eml # Order confirmation
            spam_marketing.eml       # Marketing spam
```

```go
func loadTestEmail(t *testing.T, name string) *models.Email {
    t.Helper()
    data, err := os.ReadFile(filepath.Join("testdata", "emails", name))
    require.NoError(t, err)
    email, err := ParseRawEmail(data)
    require.NoError(t, err)
    return email
}

func TestClassificationPipeline_RealEmails(t *testing.T) {
    pipeline := newTestPipeline(t)

    tests := []struct {
        fixture  string
        expected string
    }{
        {"action_question.eml", "action"},
        {"html_newsletter.eml", "newsletter"},
        {"transactional_receipt.eml", "transactional"},
        {"spam_marketing.eml", "filtered"},
    }

    for _, tt := range tests {
        t.Run(tt.fixture, func(t *testing.T) {
            email := loadTestEmail(t, tt.fixture)
            result, err := pipeline.Classify(context.Background(), email)
            assert.NoError(t, err)
            assert.Equal(t, tt.expected, result.Classification)
        })
    }
}
```

### End-to-End Test Pattern

```go
func TestE2E_EmailArrival_ToClassification_ToWebSocket(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping e2e test")
    }

    // Setup
    db := setupTestDB(t)
    store := storage.New(db)
    wsHub := api.NewWebSocketHub()
    mockLLM := &llm.MockLLMProvider{}
    pipeline := classifier.NewPipeline(store, mockLLM)
    scheduler := jobs.NewScheduler(store, wsHub, mockLLM, pipeline)

    // Start the server
    server := api.NewServer(testConfig(), store, wsHub)
    go server.ListenAndServe()
    defer server.Close()

    // Connect a WebSocket client
    ws, _, _ := websocket.DefaultDialer.Dial("ws://localhost:8080/api/v1/ws?token=test", nil)
    defer ws.Close()

    // Simulate a new email arriving
    email := &models.Email{
        ID:          uuid.New().String(),
        FromAddress: "boss@company.com",
        Subject:     "Can you handle this?",
        TextBody:    "Please review the attached proposal by tomorrow.",
    }
    store.SaveEmail(context.Background(), email)
    scheduler.ProcessNewEmail(context.Background(), email)

    // Verify WebSocket received the event
    ws.SetReadDeadline(time.Now().Add(5 * time.Second))
    _, msg, err := ws.ReadMessage()
    assert.NoError(t, err)

    var event api.WSEvent
    json.Unmarshal(msg, &event)
    assert.Equal(t, "email.new", event.Type)

    // Verify classification was saved
    classification, _ := store.GetClassification(context.Background(), email.ID)
    assert.Equal(t, "action", classification.Classification)
}
```

---

## Summary of Technology Choices

| Component | Choice | Rationale |
|---|---|---|
| Language | Go | Single binary, goroutines for IMAP, mature email ecosystem |
| HTTP framework | `net/http` (stdlib) | Sufficient for this scale, zero dependencies |
| WebSocket | `gorilla/websocket` or `nhooyr.io/websocket` | Mature, well-tested |
| IMAP client | `emersion/go-imap/v2` | Best Go IMAP library, actively maintained, extension support |
| MIME parsing | `emersion/go-message` | Same author as go-imap, well-integrated |
| SMTP | `emersion/go-sasl` + stdlib `net/smtp` or `go-mail` | Simple sending needs |
| Database | SQLite via `mattn/go-sqlite3` | WAL mode, FTS5, single-file, proven at this scale |
| Config | YAML via `gopkg.in/yaml.v3` | Human-readable, env var overrides |
| Logging | `log/slog` (stdlib) | Structured logging, Go 1.21+ standard |
| Keychain | `zalando/go-keyring` | Cross-platform keyring access |
| LLM | HTTP client to Ollama / Anthropic / OpenAI | Simple JSON over HTTP, no SDK dependencies needed |
| Testing | `testing` (stdlib) + `testify` for assertions | Standard Go testing |

---

## Open Questions

1. **go-imap v2 Gmail extension support**: Verify that go-imap v2 has packages or hooks for X-GM-MSGID, X-GM-THRID, X-GM-LABELS, and X-GM-RAW. If not, we may need to write a small extension package.

2. **SQLite write concurrency**: With MaxOpenConns(1), writes are serialized. If the classification pipeline and IMAP sync contend on writes, consider using a write queue (channel) to serialize explicitly and avoid database lock contention.

3. **Ollama availability**: What happens when Ollama is temporarily unavailable (restarting, model loading)? The classification pipeline handles this by falling back to Layer 0+1, but recommendation extraction and digest generation would need to be queued for retry.

4. **OAuth2 initial flow**: The initial OAuth2 authorization (user grants consent in browser) needs a UI. Options: (a) the native SwiftUI app handles the OAuth flow and sends tokens to the Go server, (b) the Go server temporarily serves a web page for the OAuth callback. Option (a) is cleaner since the user is already in the app.

5. **Email body storage**: Storing full HTML and text bodies in SQLite works for moderate volumes. For very large mailboxes (100k+ emails with bodies), consider storing bodies as files on disk with SQLite holding only metadata and a file path reference.

6. **Model hot-swap**: When switching LLM providers or models (e.g., upgrading from qwen2.5:7b to a newer model), the server should handle this gracefully. The current config-based approach requires a restart. Consider supporting config reload via SIGHUP.

7. **Rate limiting the API**: For a personal server, rate limiting is not critical. But if the server is ever exposed beyond Tailscale, add rate limiting middleware (e.g., `golang.org/x/time/rate`).

8. **Structured output reliability with Ollama**: Ollama's JSON mode helps, but smaller models may still produce malformed JSON. Implement robust JSON parsing with fallback: try strict parse, then try to extract JSON from a markdown code block, then fall back to regex extraction of key fields.
