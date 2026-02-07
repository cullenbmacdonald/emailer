# macOS Client Coder Memory

## Project Structure
- Working directory: `/Users/cullen/dev/emailer-macos` (git worktree on `macos/foundation` branch)
- All client code under `clients/` subdirectory (monorepo structure)
- `clients/shared/` -- EmailClientKit Swift package (models, networking, cache)
- `clients/macos/` -- macOS app as SPM package
- `clients/ios/` -- iOS app placeholder
- `clients/.swiftlint.yml` -- SwiftLint config
- `clients/Makefile` -- Build/test/lint targets

## Key Patterns
- **@main conflict**: `EmailerLib` library target excludes `EmailApp.swift`. Separate `Emailer` executable target in `Sources/EmailerApp/` has `@main`. Tests depend on `EmailerLib` only.
- **Public API**: All stores (AppState, EmailStore, etc.) and SidebarDestination are `public` so the executable target can use them.
- **Swift 6.2.3** on macOS 26.0 (arm64). SwiftLint 0.63.1 at `/opt/homebrew/bin/swiftlint`.
- **Testing framework**: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`) not XCTest.
- **Concurrency**: Swift 6 strict concurrency. All types should be `Sendable` where needed.
- **Swift language mode**: `.swiftLanguageMode(.v6)` set in all targets.
- **Stores**: `@Observable @MainActor` pattern. Tests use `@MainActor` on the suite.
- **Environment injection**: Stores injected via `.environment()` in EmailerAppMain.
- **Color tokens**: Use `Color(light:dark:)` init with NSColor appearance callback for adaptive colors.

## Completed Tasks — Phase 1 COMPLETE
- **M-1.1**: Xcode Project and EmailClientKit Package Setup
- **M-1.2**: EmailClientKit Model Layer (17 model files, 91 tests)
- **M-1.3**: EmailClientKit API Client (130 tests, mock isolation via per-session tokens)
- **M-1.4**: WebSocket Manager (actor, reconnect, ping/pong, 144 total tests)
- **M-1.5**: Local Cache Layer (LocalCache actor, OfflineActionQueue, 164 total tests)
- **M-1.6**: App Shell (NavigationSplitView, stores, coordinator, 33 macOS tests)
- **M-1.7**: Design Tokens and Shared Components (8 files, 41 macOS tests)
- **Total**: 41 macOS tests + 164 shared tests = 205 tests

## Lessons Learned
- Swift Testing runs tests concurrently across suites — mock isolation is critical
- URLSession strips httpBody before URLProtocol.startLoading() — can't verify request bodies
- URLSession.data(for:) doesn't throw on HTTP error status — must validate inside retry loop
- `@unchecked Sendable` with NSLock for thread-safe mutable shared state in tests
- SwiftLint `empty_count`: use `count >= 1` instead of `count > 0` for Int comparisons
- All types crossing module boundary (EmailerLib → Emailer) must be `public`
- `@Observable` classes in environment need `@Bindable` for two-way bindings in views

## Build Commands
- `cd clients/shared && swift build` -- builds EmailClientKit
- `cd clients/shared && swift test` -- tests EmailClientKit (164 tests)
- `cd clients/macos && swift build` -- builds macOS app
- `cd clients/macos && swift test` -- tests macOS app (41 tests)
- `cd clients && make build-macos` / `make test` / `make lint` -- Makefile targets
- SwiftLint: `cd clients && /opt/homebrew/bin/swiftlint lint --config .swiftlint.yml`
