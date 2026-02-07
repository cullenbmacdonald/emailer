# Super Email

A native email client for macOS and iOS that protects attention and prevents things from falling through the cracks. Local AI processing on a Mac Mini hub classifies, filters, and summarizes email so important things never get lost.

## Architecture

- **Go server** — IMAP ingestion, AI classification pipeline, REST + WebSocket API
- **macOS app** — SwiftUI, keyboard-first power-user interface
- **iOS app** — SwiftUI, touch-first with iPad split-view support
- **Shared client library** — `EmailClientKit` Swift package used by both apps

## Documentation

- [Product Brief](BRIEF.md) — vision, philosophy, and requirements
- [Master Plan](docs/plans/MASTER-PLAN.md) — phased implementation plan
- [API Spec](docs/plans/api-spec.yaml) — OpenAPI 3.1 (29 endpoints)
- [API Guide](docs/plans/api-guide.md) — architecture and workflows
- [Design System](docs/plans/ui-ux/design-system.md) — shared tokens and components

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | Go, PostgreSQL 16, chi, gorilla/websocket, Ollama |
| Clients | Swift 6, SwiftUI, macOS 15 / iOS 18 |
| Infra | Docker Compose, Caddy, Tailscale |
