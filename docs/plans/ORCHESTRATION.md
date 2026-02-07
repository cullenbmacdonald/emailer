# Agent Orchestration Guide

How to run parallel coding agents for the email client project using Claude Code's Agent Teams and git worktrees.

---

## Prerequisites

1. **Claude Code** with Opus 4.6
2. **Agent Teams enabled**:
   ```json
   // ~/.claude/settings.json or project .claude/settings.json
   {
     "env": {
       "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
     }
   }
   ```
3. **Git worktrees** set up (see below)
4. **Tools installed**: `golangci-lint`, `swiftlint`, PostgreSQL, Ollama

---

## Phase 0: Specification Work (Sequential)

Spec work runs in the main session, not parallel. Each step depends on the previous.

```bash
# Step 1: UI/UX Design
# In main Claude Code session:
"Use the ui-ux-designer agent to create specs for all views. Write to /docs/plans/ui-ux/"

# Step 2: API Specification (after UI/UX is done)
"Use the api-architect agent to create the API spec. Write to /docs/plans/api-spec.yaml"

# Step 3: Implementation Requirements (after API spec is done)
"Use the planner agent to create task breakdowns for server, macOS, and iOS"
```

After Phase 0, commit all specs to main:
```bash
git add docs/plans/
git commit -m "Add UI/UX specs, API spec, and implementation requirements"
```

---

## Setting Up Worktrees for Parallel Work

Before Phase 1 begins, create isolated worktrees:

```bash
# From the main repo directory
git checkout main
git pull origin main

# Create branches
git branch server/foundation main
git branch macos/foundation main
git branch ios/foundation main

# Create worktrees (sibling directories)
git worktree add ../emailer-server server/foundation
git worktree add ../emailer-macos  macos/foundation
git worktree add ../emailer-ios    ios/foundation

# Verify
git worktree list
```

Each worktree is a full checkout on its own branch:
```
/Users/cullen/dev/emailer          → main (orchestrator)
/Users/cullen/dev/emailer-server   → server/foundation
/Users/cullen/dev/emailer-macos    → macos/foundation
/Users/cullen/dev/emailer-ios      → ios/foundation
```

---

## Phase 1+: Parallel Agent Work

### Option A: Agent Teams (Recommended)

Use Claude Code's native Agent Teams to run 3 agents in parallel:

```
Create an agent team for parallel implementation:
- Teammate 1: go-server-coder working in ../emailer-server/ on server/foundation
- Teammate 2: macos-client-coder working in ../emailer-macos/ on macos/foundation
- Teammate 3: ios-client-coder working in ../emailer-ios/ on ios/foundation

Each should read their requirements from /docs/plans/ and implement the Phase 1 foundation tasks.
```

The team lead (your main session) coordinates. Teammates work independently in their worktrees and communicate via the shared task list.

**Navigation:** `Shift+Up/Down` to switch between agents, `Enter` to view, `Escape` to interrupt.

### Option B: Separate Terminal Sessions

Run 3 independent Claude Code sessions, each pointed at a worktree:

```bash
# Terminal 1: Go Server
cd ../emailer-server
claude "You are the go-server-coder. Read /docs/plans/server-requirements.md and implement Phase 1 foundation tasks."

# Terminal 2: macOS App
cd ../emailer-macos
claude "You are the macos-client-coder. Read /docs/plans/macos-requirements.md and implement Phase 1 foundation tasks."

# Terminal 3: iOS App
cd ../emailer-ios
claude "You are the ios-client-coder. Read /docs/plans/ios-requirements.md and implement Phase 1 foundation tasks."
```

### Option C: Background Subagents

From one session, launch agents in the background:

```
Run go-server-coder in the background on ../emailer-server/ to implement Phase 1 server foundation.
Run macos-client-coder in the background on ../emailer-macos/ to implement Phase 1 macOS foundation.
Run ios-client-coder in the background on ../emailer-ios/ to implement Phase 1 iOS foundation.
```

Use `Ctrl+B` to background a running agent. Check progress with `Shift+Up/Down`.

---

## Quality Gates (Enforced Automatically)

Each coder agent has PostToolUse hooks that run linting after every file edit:

- **go-server-coder**: Runs `go vet` after each edit
- **macos-client-coder**: Runs `swiftlint` after each edit
- **ios-client-coder**: Runs `swiftlint` after each edit

Before committing, agents must also run the full gate:

### Go Server
```bash
go build ./...          # compiles
go test ./...           # all tests pass
go vet ./...            # no vet warnings
golangci-lint run       # full linter suite
```

### Swift Apps
```bash
swift build             # compiles
swift test              # all tests pass
swiftlint               # linter passes
```

---

## Merging Work Back

After each phase, merge feature branches into main:

```bash
# From the main repo
cd /Users/cullen/dev/emailer

# Merge server work
git merge server/foundation --no-ff -m "Merge server foundation"

# Merge macOS work
git merge macos/foundation --no-ff -m "Merge macOS foundation"

# Merge iOS work (may need conflict resolution with macOS if shared package changed)
git merge ios/foundation --no-ff -m "Merge iOS foundation"
```

### Switching to Next Phase

```bash
# Remove old worktrees
git worktree remove ../emailer-server
git worktree remove ../emailer-macos
git worktree remove ../emailer-ios

# Create new branches for Phase 2
git branch server/core-features main
git branch macos/core-features main
git branch ios/core-features main

# Create new worktrees
git worktree add ../emailer-server server/core-features
git worktree add ../emailer-macos  macos/core-features
git worktree add ../emailer-ios    ios/core-features
```

---

## Agent Memory

All agents have `memory: project` enabled. They store learnings in `.claude/agent-memory/<agent-name>/`. This includes:

- Codebase patterns discovered during implementation
- Common errors and how to fix them
- Architectural decisions encountered
- Library-specific gotchas

Memory persists across sessions, so agents get smarter over time. Check in `.claude/agent-memory/` to version control the shared knowledge.

---

## Troubleshooting

**Agent can't find files in worktree**: Make sure the agent is `cd`'d to the correct worktree directory. Worktrees are full repo checkouts.

**Merge conflicts between macOS and iOS**: Usually in the shared `EmailClientKit` package. Resolve in favor of the most recent change and verify both apps build.

**Linter hook fails on every edit**: The hook uses `|| true` to avoid blocking, but persistent failures mean the linter config isn't set up yet. Set up linting in Phase 1 foundation first.

**Agent runs out of context**: Use Agent Teams instead of subagents for long-running implementation work. Teammates get their own context windows.
