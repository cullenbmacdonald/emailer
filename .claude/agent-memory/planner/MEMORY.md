# Planner Agent Memory

## Project Overview
- Personal email client: Go server + macOS SwiftUI + iOS SwiftUI + Ollama LLM
- Three requirements docs: server (26 tasks), macOS (21 tasks), iOS (17 tasks) = 64 total tasks
- Three phases per component: Foundation, Core Features, Advanced Features

## Key Architecture Decisions
- EmailClientKit is a shared Swift Package created by macOS agent (M-1.1 through M-1.5)
- iOS depends on EmailClientKit being ready before starting I-1.1
- macOS and iOS are separate app targets in a single Xcode project (not multiplatform)
- Server uses PostgreSQL 16 via pgx (pure Go, no CGO), chi router, gorilla/websocket
- All models use snake_case JSON with convertFromSnakeCase in Swift
- WebSocket has 11 event types, cursor-based pagination on all list endpoints

## Cross-Platform Dependencies (Critical)
- macOS M-1.1 through M-1.5 create the shared package (models, API client, WebSocket, cache)
- iOS I-1.1 cannot begin until at minimum M-1.1 + M-1.2 are complete
- Server API must be running before client Phase 2 can be fully tested end-to-end
- Server S-1.7 (health endpoint) is the first integration test point for clients

## Task ID Scheme
- S-N.N = Server tasks (S-1.1 through S-3.7)
- M-N.N = macOS tasks (M-1.1 through M-3.6)
- I-N.N = iOS tasks (I-1.1 through I-3.7)

## Files Created
- /docs/plans/server-requirements.md (26 tasks)
- /docs/plans/macos-requirements.md (21 tasks)
- /docs/plans/ios-requirements.md (17 tasks)

## Lessons Learned
- Large brainstorm files (go-server-architecture.md, swift-client-architecture.md) exceed read limits; use offset/limit to read in parts
- Keep iOS task count lower by leveraging shared package; platform-specific work is primarily UI
- Design tokens should specify exact hex values with light/dark variants for both platforms
- Each view spec (action-queue.md, etc.) contains both macOS and iOS layouts - important to reference the correct platform section
- Phase 3 "polish" tasks (M-3.6, I-3.7) depend on all other Phase 3 tasks to avoid rework
