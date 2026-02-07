# Master Implementation Plan

## Overview

This document defines the phased implementation plan for the email client. It establishes the dependency order between workstreams, how agents parallelize work, and the git workflow that enables concurrent development.

---

## Architecture Summary

```
Go Server
├── IMAP connections (go-imap v2) → 3 email accounts
├── Classification pipeline (rules + Ollama LLM)
├── PostgreSQL database (pgx driver, no CGO) + pgvector
├── REST API (chi router) + WebSocket (gorilla/websocket)
├── Background jobs (digest, snooze, cleanup)
└── Ollama (companion service for LLM inference)

Clients (thin API consumers)
├── macOS app (SwiftUI, keyboard-first)
├── iOS app (SwiftUI, touch-first)
└── Web app (React or Svelte, defering decision to later)
```

---

## Phases

### Phase 0: Specifications (Sequential — must complete before Phase 1)

Nothing gets built until the specs are agreed upon. These are the contracts that enable parallel work.

```
Step 1: UI/UX Design Specs
  Agent: ui-ux-designer
  Output: /docs/plans/ui-ux/*.md
  Covers: All 5 views + digest, all interactions, all states,
          design tokens, platform adaptations

Step 2: API Specification
  Agent: api-architect
  Output: /docs/plans/api-spec.yaml, /docs/plans/api-guide.md
  Covers: All REST endpoints, WebSocket events, data models,
          auth, errors, pagination
  Depends on: UI/UX specs (needs to know what data each view requires)

Step 3: Implementation Requirements
  Agent: planner
  Output: /docs/plans/server-requirements.md
          /docs/plans/macos-requirements.md
          /docs/plans/ios-requirements.md
  Covers: Milestones broken into tasks with acceptance criteria
  Depends on: API spec + UI/UX specs
```

**Why this order:**
- UI/UX must come first because both the API and the client implementations depend on knowing what the user sees and does.
- The API spec depends on UI/UX because each view's data needs drive the endpoint design.
- Implementation requirements depend on both specs because tasks reference specific endpoints and specific UI patterns.

---

### Phase 1: Foundation (Parallel — 3 worktrees)

Once specs are complete, three agents work simultaneously on foundational scaffolding.

```
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│   Go Server           │  │   macOS App           │  │   iOS App            │
│   Branch: server/     │  │   Branch: macos/      │  │   Branch: ios/       │
│   foundation          │  │   foundation          │  │   foundation         │
│                       │  │                       │  │                      │
│ - Project scaffolding │  │ - Xcode project setup │  │ - Xcode project setup│
│ - PostgreSQL schema + │  │ - EmailClientKit pkg  │  │ - Shared pkg import  │
│   migrations          │  │ - API client + models │  │ - API client + models│
│ - Config loading      │  │ - WebSocket manager   │  │ - WebSocket manager  │
│ - Health endpoint     │  │ - App shell + nav     │  │ - App shell + tabs   │
│ - Linting + CI setup  │  │ - Linting + CI setup  │  │ - Linting + CI setup │
│ - Test infrastructure │  │ - Test infrastructure │  │ - Test infrastructure│
└──────────────────────┘  └──────────────────────┘  └──────────────────────┘
         │                         │                         │
         ▼                         ▼                         ▼
    go test ./...           swift build + test         swift build + test
    golangci-lint run       swiftlint                  swiftlint
```

**Note:** The macOS app creates the shared `EmailClientKit` Swift package. The iOS app imports it. The macOS foundation must be slightly ahead or coordinated.

---

### Phase 2: Core Features (Parallel — 3 worktrees)

Each agent implements the core email flows for their component.

```
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│   Go Server           │  │   macOS App           │  │   iOS App            │
│                       │  │                       │  │                      │
│ Milestone: IMAP       │  │ Milestone: Action Q   │  │ Milestone: Action Q  │
│ - Account connections │  │ - Email list view     │  │ - Email list view    │
│ - IDLE + polling      │  │ - Email detail view   │  │ - Email detail view  │
│ - Email fetching      │  │ - J/K navigation      │  │ - Swipe actions      │
│ - Email storage       │  │ - Reply compose       │  │ - Reply compose      │
│                       │  │ - Snooze picker       │  │ - Snooze picker      │
│ Milestone: API        │  │                       │  │                      │
│ - Email list endpoint │  │ Milestone: Reading Q  │  │ Milestone: Reading Q │
│ - Email detail        │  │ - Newsletter list     │  │ - Newsletter list    │
│ - Classify override   │  │ - Reader view         │  │ - Reader view        │
│ - Snooze endpoints    │  │ - Reading progress    │  │ - Reading progress   │
│ - Compose/send        │  │                       │  │                      │
│ - WebSocket hub       │  │ Milestone: Cmd+K      │  │ Milestone: Search    │
│                       │  │ - Command palette     │  │ - Search bar + list  │
│ Milestone: Classify   │  │ - Fuzzy search        │  │                      │
│ - Rule-based layer    │  │ - Shortcut teaching   │  │                      │
│ - Ollama integration  │  │                       │  │                      │
│ - Classification pipe │  │                       │  │                      │
└──────────────────────┘  └──────────────────────┘  └──────────────────────┘
```

---

### Phase 3: Advanced Features (Parallel — 3 worktrees)

```
┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
│   Go Server           │  │   macOS App           │  │   iOS App            │
│                       │  │                       │  │                      │
│ Milestone: Recs       │  │ Milestone: Recs       │  │ Milestone: Recs      │
│ - Extraction pipeline │  │ - Card grid view      │  │ - Card grid view     │
│ - Dedup detection     │  │ - Type filtering      │  │ - Type filtering     │
│ - Recs API endpoints  │  │ - Status management   │  │ - Status management  │
│                       │  │                       │  │                      │
│ Milestone: Digest     │  │ Milestone: Digest     │  │ Milestone: Digest    │
│ - Generation jobs     │  │ - Digest view         │  │ - Digest view        │
│ - Digest API          │  │                       │  │                      │
│                       │  │ Milestone: Filtered   │  │ Milestone: Filtered  │
│ Milestone: Filtered   │  │ - Filtered list view  │  │ - Filtered list view │
│ - Auto-cleanup job    │  │ - Rescue action       │  │ - Rescue action      │
│ - Filtered API        │  │                       │  │                      │
│                       │  │ Milestone: All Inboxes│  │ Milestone: All In.   │
│ Milestone: Search     │  │ - Unified list view   │  │ - Unified list view  │
│ - PG full-text search │  │ - Search integration  │  │ - Search integration │
│                       │  │                       │  │                      │
│ Milestone: Multi-user │  │ Milestone: Offline    │  │ Milestone: Offline   │
│ - Cloud LLM providers │  │ - Caching layer       │  │ - Caching layer      │
│ - User auth           │  │ - Offline indicator   │  │ - Offline indicator  │
│ - Multi-tenant DB     │  │ - Action queueing     │  │ - Action queueing    │
└──────────────────────┘  └──────────────────────┘  └──────────────────────┘
```

---

## Git Workflow

### Branch Strategy

```
main
├── specs/ui-ux          ← Phase 0: UI/UX design (merged before Phase 1)
├── specs/api            ← Phase 0: API spec (merged before Phase 1)
├── specs/requirements   ← Phase 0: Task breakdown (merged before Phase 1)
│
├── server/foundation    ← Phase 1: Go scaffolding
├── macos/foundation     ← Phase 1: macOS scaffolding
├── ios/foundation       ← Phase 1: iOS scaffolding
│
├── server/imap          ← Phase 2: feature branches...
├── server/api
├── server/classify
├── macos/action-queue
├── macos/reading-queue
├── ios/action-queue
└── ...
```

### Git Worktrees for Parallel Agents

Each coding agent operates in its own worktree so they don't conflict:

```bash
# Create worktrees (run once during Phase 1 setup)
git worktree add ../emailer-server server/foundation
git worktree add ../emailer-macos  macos/foundation
git worktree add ../emailer-ios    ios/foundation
```

Each agent's working directory:
- **go-server-coder** → `../emailer-server/`
- **macos-client-coder** → `../emailer-macos/`
- **ios-client-coder** → `../emailer-ios/`

### Merge Strategy

- Feature branches merge to `main` via PR
- Server API changes that affect clients: merge server first, then update clients
- Shared `EmailClientKit` changes: coordinate between macOS and iOS agents

---

## Quality Gates

Every agent must satisfy these before committing:

### Go Server
```bash
go build ./...          # compiles
go test ./...           # all tests pass
go vet ./...            # no vet warnings
golangci-lint run       # linter passes
```

### macOS / iOS Apps
```bash
swift build             # compiles
swift test              # all tests pass
swiftlint               # linter passes
```

### Before Any PR
- All quality gates pass
- No compiler warnings
- No hardcoded secrets
- No debugging statements (print, fmt.Println)
- Commit messages are descriptive
- Branch is rebased on latest main

---

## Agent Orchestration

### Who runs when:

| Phase | Agent | Can Parallelize With |
|-------|-------|---------------------|
| 0.1 | ui-ux-designer | Nothing (first) |
| 0.2 | api-architect | Nothing (needs UI/UX) |
| 0.3 | planner | Nothing (needs API spec) |
| 1 | go-server-coder | macos-client-coder, ios-client-coder |
| 1 | macos-client-coder | go-server-coder, ios-client-coder |
| 1 | ios-client-coder | go-server-coder, macos-client-coder |
| 2+ | Same pattern — all three in parallel |

### How requirements flow:

```
BRIEF.md (product vision)
    ↓
UI/UX Specs (what the user sees)
    ↓
API Spec (data contract)
    ↓
Requirements (tasks with acceptance criteria)
    ↓
┌─────────┬─────────┬─────────┐
│ Server  │  macOS  │   iOS   │  ← parallel implementation
│ Agent   │  Agent  │  Agent  │
└─────────┴─────────┴─────────┘
    ↓           ↓          ↓
Quality Gates (tests + linting)
    ↓           ↓          ↓
PRs to main
```

---

## Definition of Done

### For a Milestone
- All tasks in the milestone have passing tests and linting
- All acceptance criteria are met
- Feature branch is merged to main
- No regressions in existing tests

### For the Entire Project (v1)
- All 5 views work on macOS and iOS
- Daily digest generates and displays
- 3 email accounts connected and classified
- Recommendations extracted from newsletters
- Snooze works end-to-end
- Search works across all emails
- Offline mode degrades gracefully
- All tests pass, all linters clean

---

## Next Steps

1. Run **ui-ux-designer** agent to create specs for all views
2. Run **api-architect** agent to create the API specification
3. Run **planner** agent to create per-component requirements
4. Set up git worktrees
5. Run **go-server-coder**, **macos-client-coder**, **ios-client-coder** in parallel
