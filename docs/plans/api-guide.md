# API Guide

> Architectural and behavioral guide for the Emailer API. This document explains *how* and *why* -- the workflows, pipelines, and client strategies that complement the formal endpoint specification.
>
> **For endpoint details, request/response schemas, and parameter documentation, see [api-spec.yaml](./api-spec.yaml).**

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Authentication](#2-authentication)
3. [Conventions](#3-conventions)
4. [Email Classification Pipeline](#4-email-classification-pipeline)
5. [View-Specific API Patterns](#5-view-specific-api-patterns)
6. [Snooze Mechanics](#6-snooze-mechanics)
7. [Training Signal Flow](#7-training-signal-flow)
8. [Account Model and Filtering](#8-account-model-and-filtering)
9. [WebSocket Integration](#9-websocket-integration)
10. [Client Error Handling Strategy](#10-client-error-handling-strategy)

---

## 1. Architecture Overview

```
+------------------+       REST / WebSocket       +------------------+
|   SwiftUI Apps   | <--------------------------> |   Go Server      |
|   (macOS, iOS)   |                              |   (chi router)   |
|                  |                              |                  |
|   Thin clients:  |                              |   - IMAP sync    |
|   - Display data |                              |   - SMTP send    |
|   - User actions |                              |   - Classify     |
|   - Local cache  |                              |   - Extract recs |
+------------------+                              |   - Gen digest   |
                                                  |   - Snooze mgmt  |
                                                  +--------+---------+
                                                           |
                                              +------------+------------+
                                              |            |            |
                                         +----+----+  +----+----+  +---+---+
                                         |PostgreSQL|  | Ollama  |  | IMAP  |
                                         | (pgx)   |  | (LLM)   |  | SMTP  |
                                         +---------+  +---------+  +-------+
```

**Go Server** -- Runs on a Mac Mini (or any server). Manages all IMAP connections, runs the AI classification pipeline via Ollama, extracts recommendations, generates daily digests, handles snooze timers, and sends email via SMTP.

**PostgreSQL** -- Stores all email metadata, classification results, recommendations, snooze states, digests, and training signals. Full-text search via `tsvector`/`tsquery`. Connection pooling via `pgxpool`.

**Ollama** -- Local LLM inference for classification and recommendation extraction. Swappable to Anthropic or OpenAI cloud APIs.

**Clients** -- Thin API consumers. They call REST endpoints to fetch data, send user actions, and maintain a WebSocket connection for real-time updates. All intelligence lives on the server.

---

## 2. Authentication

**Single-user (current):** A static API key configured in the server's `config.yaml`, passed as `Authorization: Bearer <token>` on REST requests. WebSocket connections pass the token as a `?token=` query parameter (since WebSocket upgrade requests cannot carry custom headers in all clients). The `GET /health` endpoint requires no authentication.

**Future multi-user:** The static token will be replaced with JWT tokens issued by a `/api/v1/auth/login` endpoint. The `Authorization: Bearer <jwt>` pattern remains the same -- clients will not need structural changes.

---

## 3. Conventions

- **Base URL:** All API endpoints are prefixed with `/api/v1/`. The health check (`/health`) is the only exception.
- **IDs:** UUID v4 strings.
- **Timestamps:** UTC, ISO 8601 format (`2026-02-07T14:30:00Z`). Clients may send timezone offsets; the server converts to UTC.
- **JSON fields:** `snake_case`. Swift clients use `.convertFromSnakeCase` for automatic mapping.
- **Pagination:** Cursor-based. Responses include `next_cursor` (opaque, do not parse) and `has_more`. Default limit 50, max 100.
- **Partial updates:** PATCH endpoints accept partial objects. Only included fields are changed.
- **Additive evolution:** New response fields may appear at any time without a version bump. Clients must ignore unknown fields. Removal or type changes require a new API version (`/api/v2/`).

---

## 4. Email Classification Pipeline

When a new email arrives via IMAP, the server runs it through a multi-layer classification cascade:

```
New Email
    |
    v
Layer 0: Deterministic Rules
    - VIP sender list -> action_required (always)
    - Known newsletter domains -> newsletter
    - Known spam patterns -> filtered
    - Order confirmation patterns -> transactional
    |
    v (if no rule matched)
Layer 1: Feature Scoring
    - Sender reply frequency
    - To vs CC field
    - Question marks / request language
    - Unsubscribe link presence
    - Bulk sending headers
    |
    v (if score is ambiguous)
Layer 2: LLM Classification
    - Ollama prompt with email content
    - Returns classification + confidence + reason
    |
    v
Store result -> Broadcast via WebSocket
```

**Classification values:**

| Classification | Queue | Description |
|---------------|-------|-------------|
| `action_required` | Action Queue | Needs a response from the user |
| `newsletter` | Reading Queue | Newsletter content to read at leisure |
| `filtered` | Filtered | Spam or marketing (auto-deletes after 14 days) |
| `transactional` | All Inboxes only | Receipts, shipping, calendar (auto-archived) |

**Confidence score:**

The confidence score (0.0-1.0) indicates how certain the classifier is. The Filtered view uses this to identify borderline items (confidence < 0.80) that the user should review.

---

## 5. View-Specific API Patterns

Each view in the client is powered by a combination of API calls. This section describes the *workflow* -- which endpoints each view calls and how to interpret the responses. See [api-spec.yaml](./api-spec.yaml) for full endpoint parameters and response schemas.

### Action Queue

Fetch via `GET /api/v1/emails?view=action_queue`. The server returns emails in a specific order: snoozed-returned items first (by `return_at` DESC), then new items (by `received_at` DESC). The client separates these into "RETURNING" and "NEW" sections locally based on snooze state:

- **RETURNING**: `snooze.is_active == false` and `snooze.snooze_count > 0` (snooze recently expired)
- **NEW**: Everything else

User actions: snooze (via `POST .../snooze`), archive (via `PATCH`), reply (via `POST /compose/send`).

### Reading Queue

Two-step workflow:

1. **List newsletters:** `GET /api/v1/emails?view=reading_queue` -- the `recommendation_count` field on each email drives the star badge display.
2. **Open in reader:** `GET /api/v1/emails/{id}?reader_mode=true` -- fetches the sanitized reader content. The server automatically sets `last_read_at` when fetching detail, which controls Reading Queue ordering.

**Read progress tracking:** As the user scrolls, the client periodically reports progress via `PATCH /api/v1/emails/{id}` with `read_progress` (0.0-1.0). Together `last_read_at` and `read_progress` control Reading Queue ordering:

1. **Unread** (`last_read_at` is null) -- appear first, sorted by `received_at` DESC
2. **Partially read** (`last_read_at` set, `is_read` false) -- appear second, sorted by `last_read_at` DESC
3. **Fully read** (`is_read` true) -- filtered out by default

### Filtered View

Fetch via `GET /api/v1/emails?view=filtered`. The server returns borderline items (confidence < 0.80) first. Key fields per email: `classification.confidence` (for the confidence label), `classification.reason` (for AI explanation), and `days_until_expiry` (for the countdown).

Two user actions, both via `POST /api/v1/emails/{id}/reclassify`:

- **Rescue:** `{ "new_classification": "action_required" }` -- moves to Action Queue, records training signal
- **Confirm spam:** `{ "new_classification": "filtered", "confirm": true }` -- no move, records training signal

### All Inboxes

Fetch via `GET /api/v1/emails?view=all_inboxes`. Shows all emails regardless of classification. Each email includes its `classification` for the classification badge. Search is available only from All Inboxes via `GET /api/v1/search`. Results include `highlight_snippet` with `<mark>` tags for bold rendering.

### Daily Digest

Fetch via `GET /api/v1/digests/latest` (current) or `GET /api/v1/digests/{id}` (historical via date picker). The digest is a pre-generated document -- the server computes all stats, selects borderline items, and structures sections at generation time (6:00 AM / 7:00 PM).

**Morning sections** (in order): `action_queue_summary`, `returning_today`, `reading_queue_summary`, `borderline_items`, `notable_transactional`

**Evening sections** (in order): `today_stats`, `still_pending`, `newsletters_today`, `snooze_nudges`, `notable_transactional`

Sections with no data are omitted. The client renders sections in array order. Inline actions on borderline items within the digest use the same `POST /api/v1/emails/{id}/reclassify` endpoint.

### Recommendations

Two filter axes: type (`book`, `movie`, etc.) and status (`new`, `saved`, `done`, `dismissed`). Default view shows `new` + `saved`. Fetch via `GET /api/v1/recommendations`. The `source_email_id` parameter links back to the Reading Queue (navigating from a newsletter's recommendation footer).

---

## 6. Snooze Mechanics

### How Snooze Works

1. User triggers snooze with a target return time
2. Client calls `POST /api/v1/emails/{id}/snooze` with `return_at`
3. Server creates/updates the snooze record, increments `snooze_count`
4. Server broadcasts `snooze.created` via WebSocket
5. Email disappears from the active Action Queue
6. Server's background job checks for expired snoozes every minute
7. When `return_at` passes, the server deactivates the snooze
8. Server broadcasts `snooze.returned` via WebSocket
9. Email appears at the top of the "RETURNING" section

### Multi-Snooze

An email can be snoozed multiple times. The `snooze_count` tracks total snoozes. When `snooze_count >= 2`, clients show the "snoozed 3x" badge. The evening digest surfaces emails snoozed 3+ times as "gentle nudges."

### Snooze Presets

The snooze time presets are calculated client-side:
- **2 hours**: `now + 2h`
- **Tomorrow morning**: `tomorrow 9:00 AM local`
- **Next week**: `next Monday 9:00 AM local`
- **Custom**: User enters a date/time

The client converts the local time to UTC before sending to the server.

### Cancelling Snooze

`DELETE /api/v1/emails/{id}/snooze` cancels the active snooze. The email immediately returns to the Action Queue. The `snooze_count` is NOT decremented (it is a historical counter).

---

## 7. Training Signal Flow

The classification pipeline improves over time based on user feedback. Every reclassify call records a training signal:

```
User Action                          API Call                              Training Effect
-----------                          --------                              ---------------
Rescue from Filtered to Action Q     POST /reclassify                      Override recorded:
                                     {"new_classification":                filtered -> action_required
                                      "action_required"}                   (sender, content features saved)

Confirm spam in Filtered             POST /reclassify                      Confirmation recorded:
                                     {"new_classification":                filtered confirmed
                                      "filtered", "confirm": true}         (strengthens filter for sender)

Move from Action Q to Reading Q      POST /reclassify                      Override recorded:
                                     {"new_classification":                action_required -> newsletter
                                      "newsletter"}                        (sender added to newsletter list)

Digest: "Not Spam" on borderline     POST /reclassify                      Same as rescue above
                                     {"new_classification": "..."}

Digest: "Spam" on borderline         POST /reclassify                      Same as confirm above
                                     {"new_classification":
                                      "filtered", "confirm": true}
```

Every reclassify call:
1. Changes the email's classification immediately
2. Records an entry in the `overrides` table
3. Broadcasts `classification.changed` via WebSocket
4. The classification pipeline uses override history to adjust scoring for that sender/content pattern

### Training Period

During the first two weeks, the Filtered view's borderline threshold is more aggressive (confidence < 0.85 instead of < 0.80), and the digest shows up to 5 borderline items instead of 3. This front-loads feedback collection.

---

## 8. Account Model and Filtering

### Account Structure

Three email accounts: two personal, one work. Each account has a unique UUID, display name, color (hex) for the UI dot, and account type (`work` or `personal`).

### Filtering Semantics

The global `account_id` query parameter applies across all views:

| Filter | Behavior |
|--------|----------|
| All (no `account_id`) | Show emails from all accounts |
| Work (`account_id=work-uuid`) | Show only work account emails |
| Personal (`account_id=uuid1,uuid2`) | Comma-separated UUIDs for both personal accounts |

The account filter persists across view switches. When the user selects "Work only" (Cmd+Shift+1), all views filter to work emails until changed.

**Implementation note:** For the "Personal" filter that combines both personal accounts, pass both UUIDs as a comma-separated string. The server splits the value and applies an SQL `IN` clause.

### Exception: Daily Digest

The Daily Digest always shows data from ALL accounts regardless of the global filter. Account breakdowns are shown within digest sections (e.g., "Work: 2, Personal: 1").

### Denormalized Account Fields

Account `color` and `name` are denormalized onto every Email object as `account_color` and `account_name` so the client does not need to look up accounts to render the account dot.

---

## 9. WebSocket Integration

### Connection and Keepalive

Connect to `ws://host:port/api/v1/ws?token=<token>`. All messages are JSON objects with `type`, `payload`, and `timestamp` fields. Clients send `{"type": "ping"}` every 30 seconds; server responds with `{"type": "pong"}`.

### Reconnection Strategy

If the WebSocket connection drops:
1. Reconnect with exponential backoff (1s, 2s, 4s, 8s, max 30s)
2. On reconnect, call the REST API to catch up on any missed events
3. Show the OfflineBanner while disconnected

### Event Types

All events are server-to-client unless noted. Full payload schemas are in [api-spec.yaml](./api-spec.yaml) under `components/schemas`.

| Event | Description | Client Action |
|-------|-------------|---------------|
| `email.new` | New email arrived and classified | Insert into appropriate view, update badge counts |
| `email.updated` | Email metadata changed (read, archived) | Find by ID across views, update in place |
| `email.deleted` | Email permanently deleted | Remove from all views |
| `classification.changed` | Classification overridden or reprocessed | Move email between views |
| `snooze.created` | Email was snoozed | Remove from active Action Queue |
| `snooze.returned` | Snoozed email timer expired | Insert at top of "RETURNING" section with purple accent |
| `snooze.cancelled` | Snooze was cancelled by user | Insert back into Action Queue |
| `recommendation.new` | New recommendation extracted | Insert into Recommendations if filter matches |
| `recommendation.updated` | Recommendation status changed | Update or remove from current filter |
| `digest.available` | New daily digest generated | Show "NEW" indicator on Digest tab |
| `account.status` | IMAP connection status changed | Update account status indicator |
| `ping`/`pong` | Client heartbeat (client-to-server / server-to-client) | Keepalive only |

Events carry full objects (e.g., `email.new` includes the complete Email) so clients can insert directly without additional API calls.

The WebSocket enhances the experience with real-time updates but is not required. Clients can function with REST-only by polling.

---

## 10. Client Error Handling Strategy

### Error Response Format

All errors return `{ "code": "<machine_code>", "message": "<human_text>", "details": {} }`. For validation errors, `details.fields` contains per-field messages. See the `Error` schema in [api-spec.yaml](./api-spec.yaml) for the full definition and the list of error codes.

### Client Strategy

1. **Optimistic UI**: For user actions (archive, snooze, reclassify), update the UI immediately before the API call completes.
2. **Rollback on error**: If the API call fails, reverse the optimistic update and show an error toast.
3. **Retry on 5xx**: Retry server errors with exponential backoff (1s, 2s, 4s, max 3 attempts).
4. **Do not retry 4xx**: Client errors indicate a bug or invalid state -- do not retry.
5. **Offline queueing**: When the server is unreachable, queue user actions locally and replay them when connectivity is restored.
6. **Show cached data**: Always prefer showing stale data with an OfflineBanner over showing an error screen.
