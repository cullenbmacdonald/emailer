# Emailer - Claude Code Project Guide

Personal email client: Go server + macOS/iOS SwiftUI apps.

## Documentation

Read before making changes:

- `BRIEF.md` -- product vision and requirements
- `docs/plans/MASTER-PLAN.md` -- phased implementation plan and git workflow
- `docs/plans/ORCHESTRATION.md` -- how to run parallel agents with Agent Teams
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

## Development Loop

Coder agents are self-directing. The standard workflow:

1. **User prompt:** "Check progress against requirements and implement the next task" (or similar)
2. **Agent assesses:** reads requirements doc, scans codebase for what exists, checks which acceptance criteria are already met
3. **Agent picks the next task:** first incomplete task (in ID order) whose dependencies are satisfied
4. **Agent implements:** writes code, tests, runs quality gates
5. **Agent reports back:** what was completed, what's next, any blockers or cross-agent dependencies
6. **User reviews:** checks the work, gives feedback or approves
7. **Repeat**

Agents should never go dark for too long. After completing one task, they should come up for air -- report status and wait for the user to review before continuing.

## Agent Teams (Parallel Work)

Use Claude Code Agent Teams for parallel implementation. See `docs/plans/ORCHESTRATION.md` for full setup.

- **Leader** (main session) coordinates and reviews
- **Teammates** (go-server-coder, macos-client-coder, ios-client-coder) work in their own worktrees
- Agents communicate with the leader when they hit blockers or cross-agent dependencies
- Navigation: `Shift+Up/Down` to switch between agents

## Tech Stack

- **Server:** Go 1.25+, PostgreSQL 16 (pgx), chi router, gorilla/websocket, Ollama
- **Clients:** Swift 6.0+, SwiftUI, shared `EmailClientKit` package, macOS 15 / iOS 18
- **Infra:** Docker Compose, Caddy, Tailscale

## Rules

- **Never commit without explicit user approval.** Show the changes and wait for a go-ahead.
- Never push unless explicitly asked.
- Never amend a previous commit unless explicitly asked.

## Conventions

- API fields: `snake_case` in JSON, camelCase in Swift
- IDs: UUID v4 strings
- Timestamps: UTC ISO 8601
- Pagination: cursor-based (opaque cursors)
- Go logging: `log/slog` structured logging
- Go linting: `golangci-lint`
- Swift linting: `swiftlint`
