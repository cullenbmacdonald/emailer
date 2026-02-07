# Swift Client Coder Memory

## Project Structure
- Shared package: `clients/shared/` (EmailClientKit)
- macOS app: `clients/Super Email/Super Email/Sources/Emailer/`
- iOS app: `clients/Super Email/Super Email (iOS)/Sources/EmailerIOS/`
- Xcode project: `clients/Super Email/Super Email.xcodeproj`
- macOS scheme: "Super Email (Mac)", iOS scheme: "Super Email (iOS)"

## Build Commands
- Package: `cd clients/shared && swift build` / `swift test`
- macOS: `xcodebuild -project "Super Email/Super Email.xcodeproj" -scheme "Super Email (Mac)" -destination "platform=macOS" build`
- iOS: `xcodebuild -project "Super Email/Super Email.xcodeproj" -scheme "Super Email (iOS)" -destination "generic/platform=iOS" build`

## Known Issues
- **Attachment type ambiguity**: `Testing.Attachment` conflicts with `EmailClientKit.Attachment` in test files. Cannot use `EmailClientKit.Attachment` because module has a namespace enum with same name. Fix: use `.init(...)` with type inference from function parameters (e.g., `EmailDetail(attachments: [.init(...)])`)
- **WKNavigationDelegate**: The `decidePolicyFor` delegate method requires `@MainActor` and `@escaping @MainActor @Sendable` on the closure in Swift 6 strict concurrency mode

## Completed Tasks
- M-1.1 through M-1.7 (Phase 1)
- M-2.1 (Email Row), M-2.2 (Action Queue View)
- M-2.3 (Email Detail View) -- implemented but not yet committed

## Patterns
- Views go in shared package (`clients/shared/Sources/EmailClientKit/Views/`)
- Platform-specific code uses `#if os(macOS)` / `#if os(iOS)`
- All stores use `@Observable @MainActor` pattern
- Environment injection: `@Environment(AppState.self)`, `@Environment(EmailStore.self)`
