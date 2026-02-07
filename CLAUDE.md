# Emailer - Claude Code Project Guide

Personal email client: Go server + macOS/iOS SwiftUI apps.

## Documentation

Read before making changes:

- `BRIEF.md` -- product vision and requirements
- `docs/plans/MASTER-PLAN.md` -- phased implementation plan and git workflow
- `docs/plans/ORCHESTRATION.md` -- how to run parallel agents
- `docs/plans/api-spec.yaml` -- OpenAPI 3.1 spec (29 endpoints, source of truth for all data contracts)
- `docs/plans/api-guide.md` -- architecture, classification pipeline, workflows
- `docs/plans/ui-ux/design-system.md` -- shared design tokens, components, Liquid Glass rules
- `docs/plans/ui-ux/*.md` -- per-view UI/UX specs (action-queue, reading-queue, recommendations, filtered, all-inboxes, daily-digest)
- `docs/plans/server-requirements.md` -- 26 server tasks with acceptance criteria
- `docs/plans/macos-requirements.md` -- 21 macOS tasks with acceptance criteria
- `docs/plans/ios-requirements.md` -- 17 iOS tasks with acceptance criteria

## Agents

Use the specialized agents in `.claude/agents/workflow/` for implementation:

| Agent | Purpose | Requirements Doc |
|-------|---------|-----------------|
| `go-server-coder` | Go server implementation | `server-requirements.md` |
| `macos-client-coder` | macOS SwiftUI app | `macos-requirements.md` |
| `ios-client-coder` | iOS SwiftUI app | `ios-requirements.md` |
| `worktree-manager` | Set up git worktrees for parallel work | `ORCHESTRATION.md` |

Spec agents (Phase 0 complete, use only for revisions):

| Agent | Purpose |
|-------|---------|
| `ui-ux-designer` | UI/UX view specs |
| `api-architect` | OpenAPI spec and API guide |
| `planner` | Implementation task breakdowns |

## Workflow

1. Coder agents read their requirements doc and implement tasks in order
2. Each task has acceptance criteria -- all must pass before moving on
3. Agents must pass quality gates before committing (tests + linting)
4. Parallel work uses git worktrees (see `ORCHESTRATION.md`)

## Tech Stack

- **Server:** Go 1.25+, PostgreSQL 16 (pgx), chi router, gorilla/websocket, Ollama
- **Clients:** Swift 6.0+, SwiftUI, shared `EmailClientKit` package, macOS 15 / iOS 18
- **Infra:** Docker Compose, Caddy, Tailscale

## Rules

- **Never commit without explicit user approval.** Show the changes and wait for a go-ahead.
- Never push unless explicitly asked.

## Conventions

- API fields: `snake_case` in JSON, camelCase in Swift
- IDs: UUID v4 strings
- Timestamps: UTC ISO 8601
- Pagination: cursor-based (opaque cursors)
- Go logging: `log/slog` structured logging
- Go linting: `golangci-lint`
- Swift linting: `swiftlint`
