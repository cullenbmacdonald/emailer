# Emailer - Claude Code Project Guide

Personal email client: Go server + macOS/iOS SwiftUI apps.

## Documentation

Docs live in `docs/plans/`. Read only what's relevant to your current task:

- `docs/plans/api-spec.yaml` — OpenAPI 3.1 spec (source of truth for all data contracts)
- `docs/plans/server-requirements.md` — server tasks with acceptance criteria
- `docs/plans/macos-requirements.md` — macOS tasks with acceptance criteria
- `docs/plans/ios-requirements.md` — iOS tasks with acceptance criteria
- `docs/plans/ui-ux/` — per-view UI/UX specs (read when implementing a specific view)

## Agents

| Agent | Purpose |
|-------|---------|
| `go-server-coder` | Go server implementation |
| `swift-client-coder` | Unified macOS + iOS SwiftUI app |

Use subagents (Task tool) for one-off tasks. No need for Agent Teams — work sequentially.

## Development Loop

1. User prompts the next task
2. Agent reads the relevant requirements doc, scans codebase, picks next incomplete task
3. Agent implements, tests, verifies
4. Agent reports back and waits for review
5. Repeat

## Tech Stack

- **Server:** Go 1.25+, PostgreSQL 16 (pgx), chi router, gorilla/websocket, Ollama
- **Clients:** Swift 6.0+, SwiftUI, shared `EmailClientKit` package, macOS 26 / iOS 26
- **Infra:** Docker Compose, Caddy, Tailscale

## Rules

- **Never commit without explicit user approval.**
- Never push unless explicitly asked.
- Never amend a previous commit unless explicitly asked.

## Conventions

- API fields: `snake_case` in JSON, camelCase in Swift
- IDs: UUID v4 strings
- Timestamps: UTC ISO 8601
- Pagination: cursor-based (opaque cursors)
- Go logging: `rs/zerolog` structured logging
- Go linting: `golangci-lint`
- Swift linting: `swiftlint`
