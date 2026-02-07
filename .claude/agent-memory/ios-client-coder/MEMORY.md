# iOS Client Coder Memory

## Worktree
- Path: `/Users/cullen/dev/emailer-ios`
- Branch: `ios/foundation`
- All code in: `clients/ios/`

## Completed Tasks
- **I-1.1**: App target, Package.swift (lib/exe/test split), TabDestination, MainTabView, Placeholders, Makefile
- **I-1.2**: IOSAppState, IOSAppCoordinator, IOSSidebarDestination, IOSRootView, IPadMainView, IOSSidebarView, enhanced MainTabView/MoreView with badges, AccountFilter
- **I-1.3**: DesignTokens, IOSAccountDot, IOSBadgeView, IOSSnoozeCountBadge, IOSOfflineBanner, IOSUndoToast, IOSEmptyStateView, IOSAccountFilterMenu

## Test Count
- 70 tests in 14 suites (32 from I-1.1/I-1.2, 38 from I-1.3)

## Key Patterns & Lessons
- **@MainActor for SwiftUI views**: All @Observable classes and test suites that instantiate SwiftUI views need `@MainActor`
- **SwiftLint type_name**: No underscores in type names — use `IOSFoo` prefix (not `Foo_iOS`)
- **Color as ShapeStyle**: Must qualify `.foregroundStyle(Color.snoozeFallback)` not `.foregroundStyle(.snoozeFallback)` — Swift can't infer Color from ShapeStyle protocol
- **SPM dual platform**: Package.swift needs both `.macOS(.v15)` and `.iOS(.v18)` for `swift build` to work on macOS host
- **Preview toolbar placement**: Use `.automatic` not `.topBarTrailing` in previews — the latter is iOS-only and breaks macOS SPM builds
- **.build/ runner.swift**: SwiftLint picks up auto-generated test runner — scope lint to `Sources/ Tests/`
- **TODO warnings**: IOSAppCoordinator has intentional TODO placeholders for M-1.3/M-1.4/M-1.5 dependencies

## File Inventory (clients/ios/)
### Sources/EmailerIOS/
- EmailApp_iOS.swift (excluded stub)
- TabDestination.swift
- IOSSidebarDestination.swift
- Stores/IOSAppState.swift, IOSAppCoordinator.swift
- Views/IOSRootView.swift, IPadMainView.swift, Placeholders.swift
- Views/Tabs/MainTabView.swift, MoreView.swift
- Views/Sidebar/IOSSidebarView.swift
- Views/Shared/DesignTokens.swift, IOSAccountDot.swift, IOSBadgeView.swift, IOSSnoozeCountBadge.swift, IOSOfflineBanner.swift, IOSUndoToast.swift, IOSEmptyStateView.swift, IOSAccountFilterMenu.swift

### Sources/EmailerIOSApp/
- EmailerIOSAppMain.swift

### Tests/EmailerIOSTests/
- TabDestinationTests.swift, IOSSidebarDestinationTests.swift, IOSAppStateTests.swift, IOSAppCoordinatorTests.swift, AccountFilterTests.swift, DesignTokensTests.swift, SharedComponentsTests.swift
