# Agent Orchestration Guide

How to run parallel coding agents for the email client project using Claude Code Agent Teams and git worktrees.

---

## Prerequisites

1. **Claude Code** with Opus 4.6
2. **Git worktrees** set up (see below)
3. **Tools installed**: `golangci-lint`, `swiftlint`, PostgreSQL, Ollama

---

## The Development Loop

Each coder agent is self-directing. The user drives the loop:

```
User: "Check progress against requirements and implement the next task"
  ↓
Agent: reads requirements → scans codebase → picks next incomplete task → implements → tests
  ↓
Agent: reports back — what was done, what's next, any blockers
  ↓
User: reviews work, gives feedback or approval
  ↓
Repeat
```

Agents do ONE task per cycle, then come up for air. This keeps the user in control and prevents agents from going off-track on long chains of work.

---

## Agent Teams (Primary Approach)

Use Claude Code Agent Teams to run 3 agents in parallel with communication.

### Starting a Team

From the main session (leader), create teammates:

```
Set up an agent team for Phase 1:
- Teammate 1: go-server-coder working in ../emailer-server/ on server/foundation
- Teammate 2: macos-client-coder working in ../emailer-macos/ on macos/foundation
- Teammate 3: ios-client-coder working in ../emailer-ios/ on ios/foundation

Each agent should read their requirements doc and assess current progress.
```

### Team Communication

- **Leader → Agent:** Give instructions, review work, approve commits
- **Agent → Leader:** Report completion, flag blockers, request cross-agent coordination
- **Agent → Agent:** Not direct — communicate through the leader when one agent needs something from another (e.g., iOS needs EmailClientKit from macOS)

### Navigation

- `Shift+Up/Down` — switch between agents
- `Enter` — view agent output
- `Escape` — interrupt an agent
- `Ctrl+B` — background a running agent

### Driving the Loop

Once the team is set up, the standard prompt for each agent is:

```
Check progress against your requirements and implement the next incomplete task.
```

Or more specifically:

```
Implement task S-2.1: IMAP Connection Manager
```

After each agent reports back, review their work and either approve or give feedback. Then prompt the next cycle.

---

## Setting Up Worktrees

Before starting parallel work, create isolated worktrees:

```bash
# From the main repo directory
git checkout main

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
/Users/cullen/dev/emailer          → main (leader)
/Users/cullen/dev/emailer-server   → server/foundation
/Users/cullen/dev/emailer-macos    → macos/foundation
/Users/cullen/dev/emailer-ios      → ios/foundation
```

Use the `worktree-manager` agent to automate setup and cleanup.

---

## Phase Transitions

### Merging a Phase

After all agents complete their phase:

```bash
cd /Users/cullen/dev/emailer

# Merge each agent's work
git merge server/foundation --no-ff -m "Merge server foundation"
git merge macos/foundation --no-ff -m "Merge macOS foundation"
git merge ios/foundation --no-ff -m "Merge iOS foundation"
```

### Starting the Next Phase

```bash
# Remove old worktrees
git worktree remove ../emailer-server
git worktree remove ../emailer-macos
git worktree remove ../emailer-ios

# Create new branches for the next phase
git branch server/core-features main
git branch macos/core-features main
git branch ios/core-features main

# Create new worktrees
git worktree add ../emailer-server server/core-features
git worktree add ../emailer-macos  macos/core-features
git worktree add ../emailer-ios    ios/core-features
```

---

## Quality Gates

Every agent must satisfy these before reporting a task as done:

### Go Server
```bash
make build    # compiles static binary
make test     # all tests pass (with -race)
make lint     # golangci-lint + go vet
make fmt      # auto-fix formatting
```

### macOS / iOS Apps
```bash
swift build   # compiles
swift test    # all tests pass
swiftlint     # linter passes
```

---

## Cross-Agent Dependencies

| Dependency | Details |
|-----------|---------|
| iOS depends on macOS M-1.1–M-1.5 | Shared `EmailClientKit` package must exist before iOS foundation |
| Clients depend on server API | Client integration testing needs running server endpoints |
| All agents depend on specs | Requirements and API spec are the source of truth — agents implement against them, not each other's code |

When an agent hits a cross-agent dependency that isn't ready, it should report the blocker to the leader rather than waiting silently.

---

## Alternative: Separate Terminal Sessions

If Agent Teams isn't available, run independent Claude Code sessions:

```bash
# Terminal 1: Go Server
cd ../emailer-server
claude "You are the go-server-coder. Check progress against requirements and implement the next task."

# Terminal 2: macOS App
cd ../emailer-macos
claude "You are the macos-client-coder. Check progress against requirements and implement the next task."

# Terminal 3: iOS App
cd ../emailer-ios
claude "You are the ios-client-coder. Check progress against requirements and implement the next task."
```

---

## Agent Memory

Agents store learnings in `.claude/agent-memory/<agent-name>/`. This includes codebase patterns, common errors, and architectural decisions. Memory persists across sessions.

---

## Troubleshooting

**Agent can't find files in worktree**: Make sure the agent is working in the correct worktree directory.

**Merge conflicts between macOS and iOS**: Usually in the shared `EmailClientKit` package. Resolve in favor of the most recent change and verify both apps build.

**Agent runs out of context**: Agent Teams gives each teammate its own context window. Prefer this over subagents for long-running work.

**Agent goes off-track**: Interrupt with `Escape`, review what happened, and redirect with a more specific prompt.
