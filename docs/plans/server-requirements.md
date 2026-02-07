# Go Server Implementation Requirements

> Implementation task breakdown for the Go server. Each task has a unique ID (S-N.N), acceptance criteria, dependencies, and complexity estimate. Agents should complete tasks in order within each phase, respecting dependencies.
>
> **Reference documents:**
> - [API Specification](/docs/plans/api-spec.yaml) -- canonical endpoint and schema definitions
> - [API Guide](/docs/plans/api-guide.md) -- human-readable API patterns and examples
> - [Go Server Architecture Brainstorm](/docs/brainstorms/go-server-architecture.md) -- package layout, IMAP patterns, LLM interface
> - [MASTER-PLAN.md](/docs/plans/MASTER-PLAN.md) -- phased delivery plan
>
> **Tech stack:**
> - Go 1.22+ with `log/slog` structured logging
> - PostgreSQL 16 via `pgx` (pure Go, no CGO)
> - `chi` router for HTTP
> - `gorilla/websocket` for WebSocket
> - `emersion/go-imap/v2` for IMAP
> - `emersion/go-message` for MIME parsing
> - Ollama HTTP API (swappable to Anthropic/OpenAI)
> - Docker Compose (PostgreSQL + app + Caddy)
> - Project scaffolded from `github.com/cullenbmacdonald/project-template`

---

## Phase 1: Foundation

**Goal:** Server compiles, connects to PostgreSQL, serves a health endpoint, and has all database tables ready for data.

---

### Task S-1.1: Project Scaffolding and Go Module Setup

**Complexity:** M
**Branch:** `server/foundation`
**Dependencies:** None

**Description:**
Initialize the Go module and create the project directory structure per the architecture brainstorm. Scaffold from the project template (Makefile, Docker, config patterns). Create the `cmd/server/main.go` entry point that wires together config loading and HTTP server startup. The binary should compile and print a startup log message.

**Files to create:**
- `go.mod` (module `github.com/cullenbmacdonald/emailer`)
- `go.sum`
- `cmd/server/main.go`
- `internal/config/config.go`
- `config.example.yaml`
- `Makefile` (with `build`, `test`, `lint`, `fmt`, `run` targets)
- `.golangci.yml` (linter configuration)

**Acceptance Criteria:**
- [ ] `go build ./cmd/server` produces a static binary
- [ ] Binary starts and logs "server starting on :8080" using `slog`
- [ ] `config.example.yaml` contains all configuration sections: `api`, `database`, `accounts`, `llm`, `classification`, `digest`, `cleanup`, `sync`, `logging`
- [ ] Config struct loads from YAML with environment variable overrides for: `EMAILER_PORT`, `EMAILER_AUTH_TOKEN`, `EMAILER_DB_DSN`, `EMAILER_LLM_PROVIDER`
- [ ] Config validation rejects missing required fields (returns error with field name)
- [ ] `Makefile` targets work: `make build`, `make test`, `make lint`, `make fmt`
- [ ] `internal/` directory structure matches the architecture brainstorm layout
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)
- [ ] No compiler warnings

---

### Task S-1.2: Docker Compose Setup

**Complexity:** M
**Branch:** `server/foundation`
**Dependencies:** S-1.1

**Description:**
Create Docker Compose configuration with PostgreSQL 16, the Go application, and Caddy reverse proxy. Include a multi-stage Dockerfile for the Go server that produces a minimal scratch-based image with `CGO_ENABLED=0`. PostgreSQL should use a named volume for data persistence.

**Files to create:**
- `Dockerfile`
- `docker-compose.yml`
- `Caddyfile`
- `.dockerignore`

**Acceptance Criteria:**
- [ ] `docker compose up -d` starts PostgreSQL, the Go app, and Caddy
- [ ] PostgreSQL is accessible on port 5432 with credentials from environment
- [ ] Go app container starts and connects to PostgreSQL
- [ ] Caddy proxies HTTP requests to the Go app
- [ ] Health endpoint is accessible via Caddy at `http://localhost/health`
- [ ] PostgreSQL data persists across `docker compose down` / `docker compose up`
- [ ] Dockerfile uses multi-stage build: builder stage compiles, final stage is `scratch` or `alpine` with only the binary
- [ ] `.dockerignore` excludes `.git`, `docs/`, `*.md`, test files
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.3: PostgreSQL Connection and Migration Framework

**Complexity:** M
**Branch:** `server/foundation`
**Dependencies:** S-1.1

**Description:**
Implement the database connection layer using `pgxpool` for connection pooling. Create a migration framework that embeds SQL files and applies them at startup in order. Create the `schema_migrations` tracking table. Connection DSN comes from config.

**Files to create:**
- `internal/storage/db.go` (connection setup, pool config, ping)
- `internal/storage/migrations.go` (migration runner)
- `internal/storage/migrations/` (directory for SQL files)

**Acceptance Criteria:**
- [ ] `storage.NewDB(dsn)` returns a `*pgxpool.Pool` configured with reasonable pool settings (min 2, max 10 connections)
- [ ] `storage.Ping(ctx)` verifies database connectivity
- [ ] `RunMigrations(pool)` creates `schema_migrations` table if not exists
- [ ] Migrations are embedded via `//go:embed migrations/*.sql`
- [ ] Migrations execute in filename order (e.g., `001_initial.sql` before `002_fts.sql`)
- [ ] Already-applied migrations are skipped (idempotent)
- [ ] Migration failure rolls back the failed migration and returns an error with the filename
- [ ] Unit tests cover: successful migration, idempotent re-run, failed migration rollback
- [ ] Integration test with a real PostgreSQL instance (can be skipped with `-short` flag)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.4: Database Schema -- Core Tables

**Complexity:** L
**Branch:** `server/foundation`
**Dependencies:** S-1.3

**Description:**
Create the initial migration SQL that defines all core database tables. Translate the schema from the architecture brainstorm to PostgreSQL syntax (UUID primary keys, `TIMESTAMPTZ` for timestamps, `JSONB` for structured fields, proper foreign keys and indexes). All tables should match the API spec models.

**Files to create:**
- `internal/storage/migrations/001_initial.sql`

**Tables to create:**
1. `accounts` -- email account configuration
2. `emails` -- email metadata and cached bodies
3. `classifications` -- classification results per email (1:1)
4. `classification_training` -- user override training signals
5. `snooze_states` -- snooze records per email
6. `recommendations` -- extracted recommendations
7. `recommendation_sources` -- duplicate source tracking (M:N)
8. `digests` -- generated daily digests (payload as JSONB)
9. `vip_senders` -- VIP sender list
10. `sender_stats` -- sender behavior statistics for feature classification

**Acceptance Criteria:**
- [ ] Migration runs successfully on a clean database
- [ ] All tables have UUID primary keys (generated as `gen_random_uuid()` default)
- [ ] All timestamps use `TIMESTAMPTZ` with `DEFAULT NOW()`
- [ ] Foreign keys enforce referential integrity (`ON DELETE CASCADE` where appropriate)
- [ ] Indexes exist on: `emails(account_id)`, `emails(received_at DESC)`, `emails(message_id)`, `emails(from_address)`, unique `emails(account_id, folder, uid)`, `classifications(email_id)` unique, `classifications(classification)`, `snooze_states(return_at) WHERE is_active = true`, `snooze_states(email_id)`, `recommendations(status)`, `recommendations(type)`, `vip_senders(email)` unique, `digests(generated_at DESC)`
- [ ] `emails.to_addresses` and `emails.cc_addresses` use `JSONB` type
- [ ] `digests.payload` uses `JSONB` type for the full digest sections structure
- [ ] `classifications.classification` uses a CHECK constraint for valid values: `action_required`, `newsletter`, `filtered`, `transactional`
- [ ] `recommendations.type` uses a CHECK constraint: `book`, `movie`, `tv`, `music`, `article`, `podcast`, `other`
- [ ] `recommendations.status` uses a CHECK constraint: `new`, `saved`, `done`, `dismissed`
- [ ] Migration is idempotent when run twice (no errors)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.5: Full-Text Search Setup

**Complexity:** S
**Branch:** `server/foundation`
**Dependencies:** S-1.4

**Description:**
Create a migration that adds PostgreSQL full-text search capabilities using `tsvector` and `tsquery`. Add a generated `tsvector` column to the `emails` table and a GIN index for fast search. The search vector should combine subject, from_name, from_address, and text_body with appropriate weights.

**Files to create:**
- `internal/storage/migrations/002_full_text_search.sql`

**Acceptance Criteria:**
- [ ] Migration adds a `search_vector TSVECTOR` column to `emails` table
- [ ] Column is auto-generated: `GENERATED ALWAYS AS (setweight(to_tsvector('english', coalesce(subject, '')), 'A') || setweight(to_tsvector('english', coalesce(from_name, '')), 'B') || setweight(to_tsvector('english', coalesce(from_address, '')), 'B') || setweight(to_tsvector('english', coalesce(text_body, '')), 'C')) STORED`
- [ ] A GIN index exists on `search_vector`
- [ ] Migration is idempotent
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.6: Model Layer

**Complexity:** M
**Branch:** `server/foundation`
**Dependencies:** S-1.4

**Description:**
Create Go structs for all data models that mirror the API spec schemas. Models should be dependency-free (only standard library imports). Include JSON tags matching the API spec field names (snake_case). Include helper methods for common operations.

**Files to create:**
- `internal/models/email.go` (Email, EmailDetail, Contact, Attachment, EmailUpdateRequest)
- `internal/models/classification.go` (Classification, ClassificationResult, ReclassifyRequest)
- `internal/models/snooze.go` (SnoozeState, SnoozeRequest)
- `internal/models/recommendation.go` (Recommendation, RecommendationDetail, DuplicateSource, RecommendationCreateRequest, RecommendationUpdateRequest)
- `internal/models/digest.go` (DailyDigest, DigestSection, DigestItem, AccountCount, DigestSummary)
- `internal/models/account.go` (Account, AccountCounts)
- `internal/models/vip.go` (VIPSender, VIPCreateRequest)
- `internal/models/health.go` (HealthResponse)
- `internal/models/websocket.go` (WebSocketEvent and all event payload types)
- `internal/models/compose.go` (ComposeRequest, ComposeSendResponse, Draft)
- `internal/models/search.go` (SearchResult, SearchResponse)
- `internal/models/errors.go` (APIError struct with code, message, details)
- `internal/models/pagination.go` (PaginatedResponse, cursor helpers)

**Acceptance Criteria:**
- [ ] All structs have JSON tags matching the API spec exactly (snake_case)
- [ ] All ID fields are `string` type (UUIDs)
- [ ] All timestamp fields are `time.Time`
- [ ] Enum-like fields (classification, recommendation type/status, digest type, account status) have string constants defined
- [ ] `Classification` values match API spec: `action_required`, `newsletter`, `filtered`, `transactional`
- [ ] `ClassifiedBy` values match: `rules`, `features`, `llm`, `user`
- [ ] Models have no imports from other internal packages (dependency-free)
- [ ] `APIError` implements the `error` interface
- [ ] Cursor encode/decode helpers handle base64 encoding of composite keys
- [ ] Unit tests verify JSON serialization round-trips for all model types
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.7: Health Endpoint and HTTP Server Shell

**Complexity:** M
**Branch:** `server/foundation`
**Dependencies:** S-1.3, S-1.6

**Description:**
Create the HTTP server with `chi` router, authentication middleware, CORS middleware, logging middleware, and the health check endpoint. The health endpoint should check database connectivity and return build info. Wire everything together in `main.go`.

**Files to create:**
- `internal/api/server.go` (HTTP server setup, graceful shutdown)
- `internal/api/routes.go` (route registration)
- `internal/api/middleware.go` (auth, CORS, logging, request ID)
- `internal/api/health.go` (health check handler)
- `internal/api/helpers.go` (JSON response helpers, error response helper)

**Acceptance Criteria:**
- [ ] Server starts on configured port and logs the address
- [ ] `GET /health` returns 200 with `HealthResponse` JSON including: status, version, commit, uptime_seconds, checks.database
- [ ] `GET /health` does NOT require authentication
- [ ] All other `/api/v1/*` routes return 401 without a valid Bearer token
- [ ] Auth middleware validates `Authorization: Bearer <token>` against configured token
- [ ] CORS middleware allows configurable origins
- [ ] Logging middleware logs: method, path, status code, duration, request ID (using `slog`)
- [ ] Request ID middleware generates a UUID and sets it on the context and `X-Request-ID` response header
- [ ] JSON response helper sets `Content-Type: application/json` and encodes the response
- [ ] Error response helper returns the standard `APIError` format from the API spec
- [ ] `GET /health` returns `status: "unhealthy"` with 503 when database ping fails
- [ ] Graceful shutdown on SIGINT/SIGTERM with 30-second timeout
- [ ] Build info (version, commit) injected via `-ldflags` in Makefile
- [ ] All tests pass (`go test ./...`) -- including handler tests with httptest
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.8: Storage Layer -- Email CRUD

**Complexity:** L
**Branch:** `server/foundation`
**Dependencies:** S-1.4, S-1.6

**Description:**
Implement the storage layer for emails: create, read (single + list with view-based filtering), update, delete. Support cursor-based pagination, account filtering, and view-specific ordering as defined in the API spec.

**Files to create:**
- `internal/storage/emails.go`
- `internal/storage/emails_test.go`

**Acceptance Criteria:**
- [ ] `CreateEmail(ctx, email)` inserts an email and returns it with generated ID
- [ ] `GetEmail(ctx, id)` returns a single email by ID (including classification, snooze state)
- [ ] `GetEmailDetail(ctx, id, readerMode)` returns email with full HTML/text body and attachments
- [ ] `ListEmails(ctx, opts)` supports filtering by: view (action_queue, reading_queue, filtered, all_inboxes), account_id, is_read, is_archived, cursor, limit
- [ ] `action_queue` view returns emails with `classification=action_required`, snoozed-returned first (by return_at DESC), then new (by received_at DESC); excludes actively snoozed emails
- [ ] `reading_queue` view returns `classification=newsletter`, unread first (by received_at DESC), then partially-read (by last read time)
- [ ] `filtered` view returns `classification=filtered`, borderline (confidence < 0.80) first, then standard (by received_at DESC)
- [ ] `all_inboxes` view returns all emails by received_at DESC
- [ ] Cursor-based pagination returns correct `next_cursor` and `has_more`
- [ ] `UpdateEmail(ctx, id, update)` updates only provided fields (is_read, is_archived)
- [ ] `DeleteEmail(ctx, id)` permanently deletes an email
- [ ] `CountEmailsByView(ctx, accountID)` returns per-view counts for an account (used by Account.counts)
- [ ] `days_until_expiry` is computed for filtered emails (14 - days since received)
- [ ] `recommendation_count` is populated for newsletter emails via a subquery
- [ ] All queries use parameterized statements (no SQL injection)
- [ ] Integration tests verify all query paths with test data
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-1.9: Storage Layer -- Supporting Tables

**Complexity:** L
**Branch:** `server/foundation`
**Dependencies:** S-1.4, S-1.6

**Description:**
Implement storage operations for all remaining tables: classifications, snooze_states, recommendations, digests, vip_senders, sender_stats, classification_training.

**Files to create:**
- `internal/storage/classifications.go`
- `internal/storage/snooze.go`
- `internal/storage/recommendations.go`
- `internal/storage/digests.go`
- `internal/storage/vip.go`
- `internal/storage/sender_stats.go`
- `internal/storage/search.go`
- `internal/storage/classifications_test.go`
- `internal/storage/snooze_test.go`
- `internal/storage/recommendations_test.go`
- `internal/storage/digests_test.go`
- `internal/storage/vip_test.go`
- `internal/storage/search_test.go`

**Acceptance Criteria:**
- [ ] **Classifications:** SaveClassification, GetClassification(emailID), UpdateClassification
- [ ] **Snooze:** CreateSnooze, GetActiveSnooze(emailID), DeactivateSnooze, GetExpiredSnoozes(now), UpdateSnooze
- [ ] **Recommendations:** CreateRecommendation, GetRecommendation(id), ListRecommendations(type, status, accountID, sourceEmailID, cursor, limit), UpdateRecommendationStatus, FindSimilarRecommendation(title, type) for dedup
- [ ] **Recommendation sources:** AddDuplicateSource, GetDuplicateSources(recommendationID)
- [ ] **Digests:** SaveDigest, GetLatestDigest(type), GetDigest(id), ListDigests(cursor, limit)
- [ ] **VIP:** AddVIPSender, RemoveVIPSender, ListVIPSenders, IsVIPSender(email) (checks both exact email and domain match)
- [ ] **Sender Stats:** GetSenderStats(email), UpsertSenderStats
- [ ] **Training:** RecordTrainingSignal(emailID, previousClass, newClass, isConfirm)
- [ ] **Search:** SearchEmails(query, accountID, cursor, limit) using `ts_query` and `ts_rank`; returns results with `ts_headline` for highlight_snippet
- [ ] All functions use context for cancellation
- [ ] All have integration tests with test data
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

## Phase 2: Core Features

**Goal:** Server fetches email from IMAP, classifies it, exposes all REST API endpoints, pushes real-time updates via WebSocket, and can send email via SMTP.

**Dependencies:** All Phase 1 tasks must be complete.

---

### Task S-2.1: IMAP Connection Manager

**Complexity:** XL
**Branch:** `server/imap`
**Dependencies:** Phase 1 complete

**Description:**
Implement the IMAP connection manager with goroutine-per-account architecture. Each account runs an IDLE goroutine for real-time notifications and a worker goroutine for fetch operations. Include connection pooling, exponential backoff reconnection, and OAuth2 token management. Support Gmail, iCloud (app passwords), and Microsoft 365 providers.

**Files to create:**
- `internal/imap/manager.go` (starts/stops all account goroutines, exposes NewEmails channel)
- `internal/imap/account.go` (single account: connect, authenticate, IDLE loop, worker)
- `internal/imap/idle.go` (IDLE implementation with 14-minute re-issue)
- `internal/imap/pool.go` (connection pool per account, max 3-4 connections)
- `internal/imap/oauth.go` (OAuth2 token refresh for Gmail and Microsoft 365)
- `internal/imap/provider.go` (provider-specific config: Gmail extensions, iCloud quirks)
- `internal/imap/backoff.go` (exponential backoff utility)

**Acceptance Criteria:**
- [ ] `Manager.Start(ctx)` starts IDLE + worker goroutines for each configured account
- [ ] `Manager.Stop()` gracefully shuts down all goroutines and closes connections
- [ ] `Manager.NewEmails()` returns a channel that receives newly fetched emails
- [ ] `Manager.AccountStatuses()` returns current connection status per account
- [ ] IDLE goroutine detects new mail notifications and triggers fetch
- [ ] IDLE re-issues every 14 minutes (before RFC 29-minute timeout)
- [ ] Worker goroutine fetches envelope + body for new messages
- [ ] Connection pool maintains 3-4 authenticated connections per account
- [ ] Pool verifies connection liveness with NOOP before returning
- [ ] OAuth2 tokens auto-refresh 5 minutes before expiry
- [ ] Exponential backoff on connection failures: 1s, 2s, 4s, ... up to 5 minutes max
- [ ] Authentication failure pauses the account and reports error status (no infinite retry)
- [ ] `account.status` WebSocket event fired on connection state changes
- [ ] Gmail-specific: fetch X-GM-THRID for thread ID if available
- [ ] Unit tests with mock IMAP server or interface mocking
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.2: Email Sync Pipeline

**Complexity:** L
**Branch:** `server/imap`
**Dependencies:** S-2.1, S-1.8

**Description:**
Implement the email fetch, parse, and store pipeline. When the IMAP manager reports new mail, fetch the full message, parse MIME structure with `go-message`, extract metadata (from, to, cc, subject, date, body, attachments), generate a snippet, and store in the database. Handle deduplication by message_id.

**Files to create:**
- `internal/imap/fetcher.go` (fetch message by UID, parse envelope + body)
- `internal/imap/parser.go` (MIME parsing, HTML/text body extraction, attachment listing)
- `internal/imap/sync.go` (orchestrates fetch -> parse -> store, deduplication)

**Acceptance Criteria:**
- [ ] Fetches full message (envelope + body + structure) for new UIDs
- [ ] Parses MIME structure: extracts HTML body, text body, or both
- [ ] Generates snippet from text body (first ~200 characters, whitespace normalized)
- [ ] Extracts attachments metadata: filename, mime type, size (not content)
- [ ] Handles multipart/alternative (prefers HTML, falls back to text)
- [ ] Handles multipart/mixed (body + attachments)
- [ ] Handles charset encoding (converts to UTF-8)
- [ ] Deduplicates by message_id (skips if already stored)
- [ ] Stores email in database with all metadata
- [ ] Emits the parsed email to the classification pipeline channel
- [ ] Handles malformed emails gracefully (logs warning, stores what it can)
- [ ] Test fixtures with real-world email samples (`.eml` files in `internal/testdata/emails/`)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.3: Classification Engine -- Rules and Features

**Complexity:** L
**Branch:** `server/classify`
**Dependencies:** S-1.6, S-1.9

**Description:**
Implement Layer 0 (deterministic rules) and Layer 1 (feature-based scoring) of the classification pipeline. Rules check VIP senders, known newsletter domains, transactional patterns, and no-reply addresses. Features extract header and content signals and compute per-class scores with an action bias.

**Files to create:**
- `internal/classifier/pipeline.go` (orchestrates the cascade: rules -> features -> LLM)
- `internal/classifier/rules.go` (Layer 0: VIP, newsletter domains, transactional patterns, no-reply)
- `internal/classifier/features.go` (Layer 1: feature extraction and scoring)
- `internal/classifier/pipeline_test.go`
- `internal/classifier/rules_test.go`
- `internal/classifier/features_test.go`

**Acceptance Criteria:**
- [ ] **Rules layer** returns immediate classification for: VIP senders -> action_required (1.0), known newsletter domains with List-Unsubscribe -> newsletter (0.99), transactional subject patterns -> transactional (0.95), no-reply addresses (passes to features, not action)
- [ ] **Rules layer** returns nil for ambiguous emails (passes to features)
- [ ] **Features layer** extracts: HasListUnsubscribe, IsInToField, RecipientCount, HasBulkHeaders, QuestionMarkCount, HasActionPhrases, HasDeadlineMention, BodyLength, LinkCount, HasUnsubscribeText, SenderReplyRate, SenderPriorClass
- [ ] **Features layer** scores four classes: action, newsletter, filtered, transactional
- [ ] **Action bias**: action score boosted by 1.2x multiplier
- [ ] Features layer returns classification with confidence (normalized score / total)
- [ ] **Pipeline** orchestrates: rules first, then features. If features confidence >= 0.85 accept. If action and confidence >= 0.6 accept. Otherwise escalate to LLM (next task).
- [ ] When LLM is unavailable, pipeline falls back to features result; if confidence < 0.5 defaults to action_required
- [ ] Transactional pattern matching covers: order confirmations, shipping, receipts, password resets, verification codes, calendar invites
- [ ] Action phrases detected: "can you", "could you", "would you", "let me know", "what do you think", "are you available"
- [ ] Unit tests cover all rule patterns, feature extraction, scoring, and pipeline cascade
- [ ] Test fixtures with categorized email samples
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.4: Classification Engine -- LLM Integration

**Complexity:** L
**Branch:** `server/classify`
**Dependencies:** S-2.3

**Description:**
Implement the LLM provider interface and Ollama provider. Integrate as Layer 2 of the classification pipeline for ambiguous emails. Include structured JSON output parsing with fallback for malformed responses. Implement provider selection from config.

**Files to create:**
- `internal/llm/provider.go` (LLMProvider interface)
- `internal/llm/ollama.go` (Ollama HTTP client)
- `internal/llm/anthropic.go` (Anthropic API client -- stub for future)
- `internal/llm/openai.go` (OpenAI API client -- stub for future)
- `internal/llm/structured.go` (JSON response parsing with fallback)
- `internal/llm/prompts.go` (classification and extraction prompt templates)
- `internal/llm/mock.go` (mock provider for testing)
- `internal/llm/provider_test.go`
- `internal/llm/ollama_test.go`

**Acceptance Criteria:**
- [ ] `LLMProvider` interface defines: `Classify(ctx, req) -> ClassifyResponse`, `ExtractRecommendations(ctx, req) -> ExtractResponse`, `Name() string`
- [ ] `OllamaProvider` calls `POST /api/chat` on Ollama with JSON mode
- [ ] Classification prompt matches the system prompt from the architecture brainstorm
- [ ] Structured output parser: tries strict JSON parse, then extracts JSON from markdown code block, then regex extraction of key fields
- [ ] 120-second timeout on LLM requests
- [ ] Provider returns standard error types for: timeout, connection refused, malformed response
- [ ] Pipeline integrates LLM: called when features confidence < 0.85 (and < 0.6 for action)
- [ ] LLM result with action + confidence >= 0.5 accepted as action
- [ ] LLM result with non-action + confidence < 0.8 overridden to action (high bar to exclude from action)
- [ ] `NewLLMProvider(cfg)` factory selects provider based on config (ollama/anthropic/openai)
- [ ] Anthropic and OpenAI providers are stubs that return an error ("not implemented yet")
- [ ] Mock provider allows test-controlled responses
- [ ] Unit tests cover: prompt building, response parsing, fallback behavior, pipeline integration with mock
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.5: REST API -- Email Endpoints

**Complexity:** XL
**Branch:** `server/api`
**Dependencies:** S-1.7, S-1.8, S-1.9

**Description:**
Implement all email-related REST API endpoints per the API spec: list, get detail, update, delete, reclassify, snooze, unsnooze, and attachment download. Each handler validates input, calls storage, and returns the correct response format.

**Files to create:**
- `internal/api/emails.go` (list, get, update, delete handlers)
- `internal/api/reclassify.go` (reclassify handler with training signal)
- `internal/api/snooze.go` (snooze and unsnooze handlers)
- `internal/api/attachments.go` (attachment download handler)
- `internal/api/emails_test.go`
- `internal/api/reclassify_test.go`
- `internal/api/snooze_test.go`
- `internal/api/attachments_test.go`

**Acceptance Criteria:**
- [ ] `GET /api/v1/emails` -- list emails with view, account_id, cursor, limit, is_read, is_archived parameters per API spec
- [ ] `GET /api/v1/emails/{id}` -- get email detail with optional `reader_mode` parameter
- [ ] `PATCH /api/v1/emails/{id}` -- partial update (is_read, is_archived, read_progress)
- [ ] `DELETE /api/v1/emails/{id}` -- permanent delete, returns 204
- [ ] `POST /api/v1/emails/{id}/reclassify` -- changes classification, records training signal, broadcasts `classification.changed` WebSocket event
- [ ] `POST /api/v1/emails/{id}/snooze` -- creates snooze with return_at, increments snooze_count, broadcasts `snooze.created`
- [ ] `DELETE /api/v1/emails/{id}/snooze` -- cancels active snooze, returns 409 if no active snooze, broadcasts `snooze.cancelled`
- [ ] `GET /api/v1/emails/{id}/attachments/{attachment_id}` -- returns raw attachment file with Content-Type and Content-Disposition headers
- [ ] All endpoints return proper error responses (400, 401, 404, 409, 500) per API spec error format
- [ ] Input validation: view is required enum, UUID format for IDs, return_at must be in the future
- [ ] Handler tests using `httptest.NewRecorder` and mock storage
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.6: REST API -- Search, Compose, Recommendations, Digests, Accounts, VIP

**Complexity:** XL
**Branch:** `server/api`
**Dependencies:** S-2.5

**Description:**
Implement all remaining REST API endpoints per the API spec.

**Files to create:**
- `internal/api/search.go` (full-text search endpoint)
- `internal/api/compose.go` (send, list drafts, create draft, update draft, delete draft)
- `internal/api/recommendations.go` (list, get, create, update status)
- `internal/api/digests.go` (list, get latest, get by ID, update)
- `internal/api/accounts.go` (list, get detail)
- `internal/api/vip.go` (list, add, remove)
- Tests for each handler file

**Acceptance Criteria:**
- [ ] `GET /api/v1/search` -- full-text search with q, account_id, cursor, limit; returns highlight_snippet per result; minimum query length 2
- [ ] `POST /api/v1/compose/send` -- validates ComposeRequest, stores for SMTP sending (actual SMTP in separate task)
- [ ] `GET /api/v1/compose/drafts` -- list drafts ordered by updated_at DESC with cursor pagination
- [ ] `POST /api/v1/compose/drafts` -- creates draft, returns 201
- [ ] `PUT /api/v1/compose/drafts/{id}` -- updates draft
- [ ] `DELETE /api/v1/compose/drafts/{id}` -- deletes draft, returns 204
- [ ] `GET /api/v1/recommendations` -- list with type, status, account_id, source_email_id, cursor, limit filters; default returns new + saved
- [ ] `POST /api/v1/recommendations` -- manual recommendation creation with is_user_added=true
- [ ] `GET /api/v1/recommendations/{id}` -- full detail with duplicate_sources
- [ ] `PATCH /api/v1/recommendations/{id}` -- update status
- [ ] `GET /api/v1/digests` -- list digest summaries with cursor, limit
- [ ] `GET /api/v1/digests/latest` -- latest digest with optional type filter
- [ ] `GET /api/v1/digests/{id}` -- specific digest by ID
- [ ] `PATCH /api/v1/digests/{id}` -- update digest metadata (mark as read)
- [ ] `GET /api/v1/accounts` -- list all accounts with connection status and per-view counts
- [ ] `GET /api/v1/accounts/{id}` -- single account detail
- [ ] `GET /api/v1/vip` -- list VIP senders
- [ ] `POST /api/v1/vip` -- add VIP sender, returns 409 if duplicate
- [ ] `DELETE /api/v1/vip/{id}` -- remove VIP sender, returns 204
- [ ] All 29 endpoints from the API spec are implemented (combined with S-2.5)
- [ ] Handler tests for each endpoint
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.7: WebSocket Server

**Complexity:** L
**Branch:** `server/api`
**Dependencies:** S-1.7

**Description:**
Implement the WebSocket hub that manages client connections and broadcasts events. Support all 11 server-to-client event types from the API spec. Handle client ping/pong keepalive. Authenticate via query parameter token.

**Files to create:**
- `internal/api/websocket.go` (WebSocket hub, client management, broadcast)
- `internal/api/websocket_test.go`

**Acceptance Criteria:**
- [ ] `GET /api/v1/ws?token=<token>` upgrades to WebSocket
- [ ] Rejects connection if token is invalid (401)
- [ ] `Hub.Broadcast(event)` sends JSON event to all connected clients
- [ ] Supports all 11 event types: email.new, email.updated, email.deleted, classification.changed, snooze.created, snooze.returned, snooze.cancelled, recommendation.new, recommendation.updated, digest.available, account.status
- [ ] Client `ping` messages receive `pong` response
- [ ] Dead connections are detected and removed (read timeout)
- [ ] Thread-safe client map (concurrent read/write safe)
- [ ] Events include `type`, `payload`, and `timestamp` fields per API spec
- [ ] Handles multiple simultaneous clients
- [ ] Client disconnection is handled gracefully (no panics)
- [ ] Integration test with `gorilla/websocket` test client
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.8: Email Processing Pipeline (IMAP -> Classify -> Store -> Broadcast)

**Complexity:** L
**Branch:** `server/pipeline`
**Dependencies:** S-2.1, S-2.2, S-2.3, S-2.4, S-2.7

**Description:**
Wire together the full email processing pipeline: IMAP manager delivers new emails -> classification pipeline runs -> result stored in DB -> WebSocket broadcast. Run as a background worker goroutine. Handle newsletter emails by queuing them for recommendation extraction.

**Files to create:**
- `internal/jobs/scheduler.go` (background job scheduler, starts all workers)
- `internal/jobs/classification_worker.go` (listens on new email channel, classifies, stores, broadcasts)

**Acceptance Criteria:**
- [ ] Scheduler starts classification worker goroutine
- [ ] Worker reads from `imap.Manager.NewEmails()` channel
- [ ] For each email: classify -> save classification -> save email with classification -> broadcast `email.new` via WebSocket
- [ ] If classified as `newsletter`, email is queued for recommendation extraction (channel)
- [ ] If classified as `transactional`, email is auto-archived (is_archived=true)
- [ ] Account color and name are denormalized onto the email object before broadcast
- [ ] Errors in classification log a warning but do not block the pipeline (default to action_required)
- [ ] Worker respects context cancellation for graceful shutdown
- [ ] Integration test: inject test email -> verify classification stored + WebSocket event sent
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.9: Snooze Scheduler

**Complexity:** M
**Branch:** `server/jobs`
**Dependencies:** S-2.7, S-1.9

**Description:**
Implement the background snooze checker that runs every minute, finds expired snoozes, deactivates them, and broadcasts `snooze.returned` events.

**Files to create:**
- `internal/jobs/snooze_checker.go`
- `internal/jobs/snooze_checker_test.go`

**Acceptance Criteria:**
- [ ] Runs every 60 seconds via a ticker
- [ ] Queries `snooze_states WHERE is_active = true AND return_at <= now()`
- [ ] For each expired snooze: sets `is_active = false` in DB
- [ ] Broadcasts `snooze.returned` WebSocket event with the full email object
- [ ] Handles empty result set gracefully (no error)
- [ ] Respects context cancellation for shutdown
- [ ] Does not process the same snooze twice (atomic update with row lock)
- [ ] Unit test with mock storage verifying event broadcast
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-2.10: SMTP Sending

**Complexity:** L
**Branch:** `server/smtp`
**Dependencies:** S-2.6

**Description:**
Implement SMTP email sending for compose, reply, reply-all, and forward. Handle per-account SMTP configuration, OAuth2 authentication for Gmail/Microsoft, app passwords for iCloud. Build proper MIME messages with threading headers. Save sent copies to IMAP Sent folder (except Gmail).

**Files to create:**
- `internal/smtp/sender.go` (SMTP connection, authentication, send)
- `internal/smtp/builder.go` (MIME message building: plain text, reply threading headers, forward with attachments)
- `internal/smtp/drafts.go` (draft save/update/delete to IMAP Drafts folder)
- `internal/smtp/sender_test.go`
- `internal/smtp/builder_test.go`

**Acceptance Criteria:**
- [ ] `Send(ctx, accountID, compose)` connects to account's SMTP server and sends the message
- [ ] Sets `In-Reply-To` and `References` headers when `in_reply_to` is provided
- [ ] Sets `From` address from the account configuration
- [ ] Forward includes original body below separator and original attachments
- [ ] Gmail: uses XOAUTH2 authentication, does NOT save sent copy (Gmail auto-saves)
- [ ] iCloud: uses PLAIN authentication with app password
- [ ] Microsoft 365: uses XOAUTH2 authentication
- [ ] Saves sent copy to IMAP Sent folder for non-Gmail accounts
- [ ] Draft operations: save to IMAP Drafts folder, update (delete old + append new), delete
- [ ] Returns the RFC 2822 Message-ID of the sent message
- [ ] Proper error types for: connection failure, auth failure, recipient rejection
- [ ] Unit tests for MIME message building (verify headers, body structure)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

## Phase 3: Advanced Features

**Goal:** Recommendations extracted from newsletters, daily digests generated, full-text search works, filtered auto-cleanup runs, VIP and training signals improve classification.

**Dependencies:** All Phase 2 tasks must be complete.

---

### Task S-3.1: Recommendation Extraction Pipeline

**Complexity:** L
**Branch:** `server/recommendations`
**Dependencies:** Phase 2 complete

**Description:**
Implement the recommendation extraction pipeline that processes newsletter emails using the LLM. Extract structured recommendations (books, movies, music, articles, podcasts, other) with title, creator, context, and confidence. Handle deduplication across newsletters. Broadcast new recommendations via WebSocket.

**Files to create:**
- `internal/recommender/extractor.go` (LLM-based extraction from newsletter text)
- `internal/recommender/dedup.go` (fuzzy title matching for duplicate detection)
- `internal/recommender/types.go` (extraction prompt templates)
- `internal/jobs/recommendation_worker.go` (background worker processing newsletter queue)
- `internal/recommender/extractor_test.go`
- `internal/recommender/dedup_test.go`

**Acceptance Criteria:**
- [ ] Worker reads from newsletter queue channel (emails classified as `newsletter`)
- [ ] Calls `LLMProvider.ExtractRecommendations()` with newsletter body text
- [ ] Extraction prompt matches the architecture brainstorm template
- [ ] Parsed recommendations include: type, title, creator, context snippet, confidence
- [ ] Deduplication: fuzzy title match (case-insensitive, whitespace-normalized) within same type
- [ ] Duplicate found: increments `duplicate_count`, adds source to `recommendation_sources`
- [ ] New recommendation: creates record, broadcasts `recommendation.new` via WebSocket
- [ ] Handles LLM returning zero recommendations (some newsletters have none)
- [ ] Handles malformed LLM responses gracefully (logs warning, skips)
- [ ] Updates email's `recommendation_count` field after extraction
- [ ] Unit tests with mock LLM returning fixture responses
- [ ] Dedup tests verify exact match, case-insensitive match, and non-match
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.2: Daily Digest Generation

**Complexity:** XL
**Branch:** `server/digest`
**Dependencies:** Phase 2 complete

**Description:**
Implement digest generation for morning (6:00 AM) and evening (7:00 PM) digests. Query the database for all required stats and items, assemble the structured digest payload per the API spec, store it, and broadcast availability. Schedule generation using a background goroutine that calculates the next digest time.

**Files to create:**
- `internal/digest/generator.go` (assembles digest sections by querying DB)
- `internal/digest/scheduler.go` (calculates next digest time, sleeps until then)
- `internal/jobs/digest_scheduler.go` (background job integration)
- `internal/digest/generator_test.go`
- `internal/digest/scheduler_test.go`

**Acceptance Criteria:**
- [ ] **Morning digest sections** (in order): action_queue_summary, returning_today, reading_queue_summary, borderline_items, notable_transactional
- [ ] **Evening digest sections** (in order): today_stats, still_pending, newsletters_today, snooze_nudges, notable_transactional
- [ ] `action_queue_summary`: count of unarchived action_required emails, per-account breakdown
- [ ] `returning_today`: snooze states where return_at is today, with email subject and sender
- [ ] `reading_queue_summary`: count of unarchived newsletter emails
- [ ] `borderline_items`: top 3 filtered emails with confidence < 0.80 (5 during training period), with sender, subject, confidence, AI reason
- [ ] `notable_transactional`: packages arriving (keywords: "shipped", "out for delivery"), large charges (dollar amounts > $100 in subject)
- [ ] `today_stats` (evening): count of emails sent and archived today
- [ ] `still_pending` (evening): count of unarchived action_required emails
- [ ] `newsletters_today` (evening): list of newsletters arrived today with name and subject
- [ ] `snooze_nudges` (evening): emails snoozed 3+ times with snooze count and days since first snooze
- [ ] Sections with no data are omitted from the payload
- [ ] Digest stored in DB with full JSONB payload
- [ ] `digest.available` WebSocket event broadcast after generation
- [ ] Scheduler calculates next 6am or 7pm, sleeps until then (respects configured timezone)
- [ ] Handles server restart mid-day (generates any missed digests for today)
- [ ] Unit tests with seeded test data verify each section's queries
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.3: Filtered Auto-Cleanup

**Complexity:** S
**Branch:** `server/jobs`
**Dependencies:** Phase 2 complete

**Description:**
Implement the background job that auto-deletes filtered emails older than 14 days. Runs every hour. Broadcasts `email.deleted` events for each removed email.

**Files to create:**
- `internal/jobs/cleanup.go`
- `internal/jobs/cleanup_test.go`

**Acceptance Criteria:**
- [ ] Runs every hour via a ticker
- [ ] Deletes emails where `classification = 'filtered'` AND `received_at < now() - interval '14 days'`
- [ ] Broadcasts `email.deleted` WebSocket event for each deleted email
- [ ] Logs count of deleted emails
- [ ] Handles empty result set gracefully
- [ ] Retention period configurable via `cleanup.filtered_retention_days` config
- [ ] Unit test verifying correct cutoff date calculation
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.4: VIP Sender Integration

**Complexity:** S
**Branch:** `server/classify`
**Dependencies:** S-2.3

**Description:**
Wire VIP sender list into the classification rules layer. VIP senders should be loaded from the database (not just config) and checked at classification time. Support both exact email addresses and domain matching (e.g., `@important-client.com`).

**Files to create:**
- `internal/classifier/vip.go` (VIP list management, domain matching)
- `internal/classifier/vip_test.go`

**Acceptance Criteria:**
- [ ] Rules layer loads VIP senders from database at startup and caches them
- [ ] Cache refreshes when VIP sender is added/removed via API (via callback or periodic refresh)
- [ ] Exact email match: `boss@company.com` matches `boss@company.com`
- [ ] Domain match: `@company.com` matches `anyone@company.com`
- [ ] VIP match -> classification `action_required` with confidence 1.0, classified_by `rules`
- [ ] Unit tests for exact match, domain match, no match, cache refresh
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.5: Training Signal Pipeline

**Complexity:** M
**Branch:** `server/classify`
**Dependencies:** S-2.5, S-2.3

**Description:**
Implement the feedback loop where reclassify actions improve future classification. When a user reclassifies an email, update sender_stats, record the training signal, and adjust the feature classifier's behavior for that sender.

**Files to create:**
- `internal/classifier/feedback.go` (processes overrides, updates sender stats)
- `internal/classifier/feedback_test.go`

**Acceptance Criteria:**
- [ ] `ProcessOverride(ctx, emailID, newClassification, isConfirm)` called from reclassify handler
- [ ] Records training signal in `classification_training` table
- [ ] Updates `sender_stats.most_common_class` based on override history
- [ ] If sender has 3+ overrides to the same class, that class is stored in sender_stats and used as a strong signal in feature scoring
- [ ] `confirm=true` reclassify calls strengthen the existing classification (increase sender_stats count for that class)
- [ ] False negative detection: logs a warning when email is rescued from filtered to action_required
- [ ] Training period logic: first 2 weeks use more aggressive borderline threshold (0.85 instead of 0.80)
- [ ] Unit tests verify sender stats updates and training signal recording
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.6: HTML Sanitization and Reader Mode

**Complexity:** M
**Branch:** `server/api`
**Dependencies:** S-2.5

**Description:**
Implement server-side HTML sanitization for email bodies. Strip tracking pixels, remove JavaScript, proxy external images. For `reader_mode=true`, additionally strip newsletter chrome (unsubscribe footers, social buttons, redundant headers).

**Files to create:**
- `internal/sanitizer/sanitize.go` (HTML sanitization: strip scripts, tracking pixels, dangerous elements)
- `internal/sanitizer/reader.go` (reader mode: strip newsletter chrome)
- `internal/sanitizer/sanitize_test.go`
- `internal/sanitizer/reader_test.go`

**Acceptance Criteria:**
- [ ] Removes all `<script>` tags and inline JavaScript event handlers
- [ ] Removes tracking pixels (1x1 images, known tracking domains)
- [ ] Strips `<style>` tags that contain external imports
- [ ] Preserves inline images and standard content images
- [ ] Reader mode strips: unsubscribe footers, "View in browser" links, social media share buttons, redundant header/logo images (keeps first)
- [ ] Reader mode preserves: article content, heading structure, blockquotes, links, images
- [ ] Output is valid HTML
- [ ] Test fixtures with real newsletter HTML (anonymized)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

### Task S-3.7: Account Status Monitoring

**Complexity:** S
**Branch:** `server/imap`
**Dependencies:** S-2.1, S-2.7

**Description:**
Wire IMAP connection status changes into the health endpoint and WebSocket. Track per-account status (online, offline, error, syncing) and broadcast changes. Update the health endpoint to include IMAP status in the checks.

**Files to create:**
- `internal/imap/status.go` (status tracking, event emission)

**Acceptance Criteria:**
- [ ] `Manager.AccountStatuses()` returns `map[accountID]status` with online/offline/error/syncing
- [ ] Status changes broadcast `account.status` WebSocket event with account_id, status, status_message
- [ ] Health endpoint includes `checks.imap` with per-account status
- [ ] Health returns `degraded` if any account is offline/error, `unhealthy` if all are
- [ ] Status transitions: syncing (initial connect) -> online (IDLE active), online -> offline (connection lost), offline -> online (reconnected), any -> error (auth failure)
- [ ] All tests pass (`go test ./...`)
- [ ] Linter passes (`golangci-lint run`)

---

## Summary

| Phase | Task Count | Key Deliverables |
|-------|-----------|-----------------|
| Phase 1 | 9 tasks | Compiles, schema, health endpoint, storage layer, models |
| Phase 2 | 10 tasks | IMAP sync, classification, all 26 API endpoints, WebSocket, SMTP |
| Phase 3 | 7 tasks | Recommendations, digests, search, auto-cleanup, training feedback |
| **Total** | **26 tasks** | |

### Dependency Graph (Critical Path)

```
S-1.1 -> S-1.2 (Docker)
S-1.1 -> S-1.3 -> S-1.4 -> S-1.5 (DB + schema)
S-1.1 -> S-1.6 (models, parallel with DB)
S-1.4 + S-1.6 -> S-1.8 (email storage)
S-1.4 + S-1.6 -> S-1.9 (other storage)
S-1.3 + S-1.6 -> S-1.7 (HTTP server)

S-1.8 -> S-2.1 -> S-2.2 (IMAP)
S-1.6 + S-1.9 -> S-2.3 -> S-2.4 (classification)
S-1.7 + S-1.8 + S-1.9 -> S-2.5 -> S-2.6 (API endpoints)
S-1.7 -> S-2.7 (WebSocket)
S-2.1 + S-2.2 + S-2.3 + S-2.4 + S-2.7 -> S-2.8 (pipeline)
S-2.7 + S-1.9 -> S-2.9 (snooze scheduler)
S-2.6 -> S-2.10 (SMTP)

Phase 2 complete -> S-3.1 (recommendations)
Phase 2 complete -> S-3.2 (digest)
Phase 2 complete -> S-3.3 (cleanup)
S-2.3 -> S-3.4 (VIP integration)
S-2.5 + S-2.3 -> S-3.5 (training signals)
S-2.5 -> S-3.6 (sanitizer)
S-2.1 + S-2.7 -> S-3.7 (account status)
```
