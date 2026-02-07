# API Architect Agent Memory

## Project Context
- Personal email client: Go server + SwiftUI clients (macOS, iOS)
- Three email accounts (2 personal, 1 work), unified into 5 views + digest
- Server handles IMAP, SMTP, classification (Ollama LLM), recommendations, digests
- Database: PostgreSQL via pgx (changed from SQLite -- see server architecture doc caveat)
- All clients are thin API consumers -- REST + WebSocket

## Key API Decisions Made

### Pagination
- Cursor-based pagination (not offset-based) for stability with real-time updates
- Opaque cursor strings -- clients must not parse them
- Default limit 50, max 100

### Authentication
- Single-user: static Bearer token from config.yaml
- WebSocket auth via `?token=` query parameter (WebSocket can't carry custom headers everywhere)
- Health endpoint `/health` requires no auth

### JSON Conventions
- All fields: `snake_case` (Swift clients use `.convertFromSnakeCase`)
- All timestamps: UTC ISO 8601
- All IDs: UUID v4 strings

### View Mapping
- `action_queue` -> classification `action_required`
- `reading_queue` -> classification `newsletter`
- `filtered` -> classification `filtered`
- `all_inboxes` -> all classifications (including `transactional`)

### Denormalization
- `account_color` and `account_name` on every Email object (avoids client-side account lookups)
- `recommendation_count` on newsletter emails (for Reading Queue star badge)
- `days_until_expiry` on filtered emails (for countdown display)

## Files Created
- `/docs/plans/api-spec.yaml` -- OpenAPI 3.1 specification (canonical source for endpoints, schemas, parameters)
- `/docs/plans/api-guide.md` -- Architectural/behavioral guide (workflows, pipelines, client strategies)
  - Refactored 2026-02-07: removed all duplicated endpoint/schema/model docs, now strictly complementary to api-spec.yaml
  - Guide covers: architecture, classification pipeline, view workflows, snooze mechanics, training signals, account filtering, WebSocket integration, error handling strategy
  - No endpoint parameter tables, no request/response JSON examples, no data model field tables, no endpoint summary appendix

## Design Patterns
- Reclassify endpoint doubles as training signal recorder (every override trains the model)
- Digest sections are polymorphic (type field determines payload shape)
- WebSocket events carry full Email objects so clients can insert directly
- Snooze is a separate sub-resource: POST/DELETE on `/emails/{id}/snooze`
- Account filter supports comma-separated UUIDs for "Personal" group filter
- Attachment download returns raw bytes (not JSON) with Content-Type/Content-Disposition headers
- `last_read_at` is server-set (on GET detail), `read_progress` is client-reported (via PATCH)
- Digest `is_read` is updatable via PATCH /digests/{id}

## Gap Fix Log (2026-02-07)
- Added: GET /emails/{id}/attachments/{attachment_id} (raw file download)
- Added: GET /compose/drafts (paginated draft list, DraftListResponse schema)
- Added: PATCH /digests/{id} (mark as read, DigestUpdateRequest schema)
- Fixed: AccountFilter parameter now accepts comma-separated UUIDs (removed format: uuid)
- Added: `last_read_at` and `read_progress` fields on Email schema
- Added: `read_progress` to EmailUpdateRequest for client scroll reporting
