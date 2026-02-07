# iOS Client Coder Memory

## Naming Convention (Critical)
- SwiftLint disallows underscores in type names (`type_name` rule)
- Use `IOS` prefix: `IOSAppState`, `IOSAppCoordinator`, `IOSRootView`
- Use `IPad` prefix: `IPadMainView`
- File names match type names

## Swift 6 Strict Concurrency
- `@Observable` + `Sendable` on a class with mutable stored properties = compile error
- Solution: `@MainActor @Observable` (no Sendable)
- Tests for `@MainActor` classes need `@MainActor` on each test method

## Project Structure (clients/ios/)
- `Package.swift` — platforms: macOS 15 + iOS 18 (macOS needed for `swift build` on host)
- `Sources/EmailerIOS/` — lib target (EmailerIOSLib), testable
- `Sources/EmailerIOSApp/` — executable target (EmailerIOS), @main entry point
- `Tests/EmailerIOSTests/` — test target
- Views: `Views/Tabs/`, `Views/Sidebar/`, `Views/Placeholders.swift`
- Stores: `Stores/IOSAppState.swift`, `Stores/IOSAppCoordinator.swift`
- iPad: `Views/IPadMainView.swift`, `Views/Sidebar/IOSSidebarView.swift`

## Phase 1 Status
- I-1.1 complete: Package setup, TabView, EmailClientKit dependency
- I-1.2 complete: AppState, AppCoordinator (stubbed), iPad NavigationSplitView, badges, More tab with NEW indicator
- I-1.3 next: iOS design tokens and shared components

## Dependencies
- M-1.1 cherry-picked onto ios/foundation (commit 788879d)
- M-1.2 models landed in EmailClientKit (macOS agent)
- M-1.3 (API client) still needed for real coordinator wiring
