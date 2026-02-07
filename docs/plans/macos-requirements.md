# macOS App Implementation Requirements

> Implementation task breakdown for the macOS SwiftUI app. Each task has a unique ID (M-N.N), acceptance criteria, dependencies, and complexity estimate. Agents should complete tasks in order within each phase, respecting dependencies.
>
> **Reference documents:**
> - [API Specification](/docs/plans/api-spec.yaml) -- canonical endpoint and schema definitions
> - [API Guide](/docs/plans/api-guide.md) -- human-readable API patterns and examples
> - [Design System](/docs/plans/ui-ux/design-system.md) -- shared tokens, components, patterns
> - [Action Queue Spec](/docs/plans/ui-ux/action-queue.md)
> - [Reading Queue Spec](/docs/plans/ui-ux/reading-queue.md)
> - [Recommendations Spec](/docs/plans/ui-ux/recommendations.md)
> - [Filtered Spec](/docs/plans/ui-ux/filtered.md)
> - [All Inboxes Spec](/docs/plans/ui-ux/all-inboxes.md)
> - [Daily Digest Spec](/docs/plans/ui-ux/daily-digest.md)
> - [Swift Client Architecture Brainstorm](/docs/brainstorms/swift-client-architecture.md) -- project layout, store pattern, keyboard system, WKWebView
> - [MASTER-PLAN.md](/docs/plans/MASTER-PLAN.md) -- phased delivery plan
>
> **Tech stack:**
> - Swift 6.0+ with strict concurrency
> - SwiftUI (macOS 15 Sequoia minimum deployment target)
> - `@Observable` for state management
> - URLSession async/await for networking (no external dependencies)
> - WKWebView (NSViewRepresentable) for email HTML rendering
> - Local Swift Package: `EmailClientKit` (shared with iOS)
> - Single Xcode project with two app targets (macOS, iOS) and one local package
>
> **Project structure:**
> - `Packages/EmailClientKit/` -- shared Swift package (models, networking, cache)
> - `macOS/` -- macOS app target
> - `iOS/` -- iOS app target (separate requirements doc)

---

## Phase 1: Foundation

**Goal:** macOS app compiles, displays a NavigationSplitView shell with sidebar, connects to the server health endpoint, and has the shared EmailClientKit package with all models and networking ready.

---

### Task M-1.1: Xcode Project and EmailClientKit Package Setup

**Complexity:** L
**Branch:** `macos/foundation`
**Dependencies:** None

**Description:**
Create the Xcode project with two app targets (macOS, iOS) and one local Swift package (`EmailClientKit`). The macOS target should be named `Emailer` with bundle ID `com.cullenbmacdonald.emailer.macos`, deployment target macOS 15. The iOS target should be named `Emailer` with bundle ID `com.cullenbmacdonald.emailer.ios`, deployment target iOS 18. Both depend on the local `EmailClientKit` package. Configure SwiftLint for both targets.

**Files to create:**
- `EmailApp.xcodeproj` (or `.xcworkspace`)
- `Packages/EmailClientKit/Package.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/EmailClientKit.swift` (empty namespace)
- `Packages/EmailClientKit/Tests/EmailClientKitTests/EmailClientKitTests.swift`
- `macOS/EmailApp_macOS.swift` (App entry point, minimal)
- `iOS/EmailApp_iOS.swift` (App entry point, minimal placeholder)
- `.swiftlint.yml` (linter configuration)
- `Makefile` (with `build-macos`, `build-ios`, `test`, `lint` targets)

**Acceptance Criteria:**
- [ ] `swift build` in `Packages/EmailClientKit/` succeeds
- [ ] `swift test` in `Packages/EmailClientKit/` succeeds (placeholder test)
- [ ] macOS app target compiles and launches showing an empty window
- [ ] iOS app target compiles (placeholder, does not need to run for this task)
- [ ] Both app targets depend on `EmailClientKit`
- [ ] `Package.swift` specifies platforms: `.macOS(.v15)`, `.iOS(.v18)`
- [ ] SwiftLint config exists and `swiftlint` runs without errors
- [ ] `Makefile` targets work: `make build-macos`, `make test`, `make lint`
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.2: EmailClientKit -- Model Layer

**Complexity:** L
**Branch:** `macos/foundation`
**Dependencies:** M-1.1

**Description:**
Create all shared model structs in EmailClientKit matching the API spec schemas exactly. All models conform to `Codable`, `Identifiable`, `Sendable`, and `Equatable`. Use `convertFromSnakeCase`/`convertToSnakeCase` key coding strategies. Configure a shared `JSONDecoder.apiDecoder` and `JSONEncoder.apiEncoder` with ISO 8601 date handling.

**Files to create:**
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/Email.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/EmailDetail.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/Classification.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/SnoozeState.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/Recommendation.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/DailyDigest.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/Account.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/VIPSender.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/ComposeRequest.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/SearchResult.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/PaginatedResponse.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/APIError.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/WebSocketEvent.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Models/HealthResponse.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Utilities/JSONCoding.swift`
- Tests for all models

**Acceptance Criteria:**
- [ ] All model structs conform to `Codable`, `Identifiable`, `Sendable`, `Equatable`
- [ ] JSON encoding/decoding round-trips match the API spec field names (snake_case in JSON, camelCase in Swift)
- [ ] `Email` model includes: id, accountID, messageID, threadID, from (Contact), to, cc, subject, snippet, receivedAt, isRead, isArchived, hasAttachments, snoozeState, labels, accountName, accountColor, snoozeCount, classification, classifiedBy, classificationConfidence, recommendationCount, daysUntilExpiry
- [ ] `EmailDetail` includes: all Email fields plus htmlBody, textBody, readerHtml, attachments array
- [ ] `Classification` enum: actionRequired, newsletter, filtered, transactional (raw values match API: `action_required`, `newsletter`, `filtered`, `transactional`)
- [ ] `Recommendation` model includes: id, type, title, creator, sourceNewsletterName, sourceEmailId, sourceDate, contextSnippet, status, duplicateCount, isUserAdded, createdAt, updatedAt
- [ ] `RecommendationType` enum: book, movie, tv, music, article, podcast, other
- [ ] `RecommendationStatus` enum: new, saved, done, dismissed
- [ ] `DailyDigest` model includes: id, generatedAt, digestType, sections array, each section with type, title, data
- [ ] `WebSocketEvent` decodes discriminated union on `type` field per API spec (11 event types)
- [ ] `PaginatedResponse<T>` is generic with items, nextCursor, hasMore
- [ ] `APIError` conforms to `LocalizedError` with httpError, decodingError, serverUnreachable, invalidResponse cases
- [ ] `JSONDecoder.apiDecoder` uses `.convertFromSnakeCase` and `.iso8601` date decoding
- [ ] `JSONEncoder.apiEncoder` uses `.convertToSnakeCase` and `.iso8601` date encoding
- [ ] Unit tests verify JSON round-trip for every model type using fixture JSON matching the API spec examples
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.3: EmailClientKit -- API Client

**Complexity:** XL
**Branch:** `macos/foundation`
**Dependencies:** M-1.2

**Description:**
Create the `APIClient` actor that handles all REST communication with the Go server. Implement every endpoint from the API spec. Use URLSession async/await. Include Bearer token authentication, retry logic for GET requests, and proper error mapping. The client receives its base URL and auth token at initialization.

**Files to create:**
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Emails.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Search.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Compose.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Recommendations.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Digests.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+Accounts.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/APIClient+VIP.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/RetryPolicy.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/ServerDiscovery.swift`
- Tests with mock URLProtocol

**Acceptance Criteria:**
- [ ] `APIClient` is an `actor` for thread-safe access
- [ ] All requests include `Authorization: Bearer <token>` header
- [ ] All requests set `Content-Type: application/json` for POST/PATCH/PUT
- [ ] **Email endpoints:** `fetchEmails(view:accountID:cursor:limit:isRead:isArchived:)`, `fetchEmailDetail(id:readerMode:)`, `updateEmail(id:isRead:isArchived:)`, `deleteEmail(id:)`, `reclassifyEmail(id:classification:confirm:)`, `snoozeEmail(id:returnAt:)`, `unsnoozeEmail(id:)`
- [ ] **Search:** `search(query:accountID:cursor:limit:)` with 2-character minimum validation
- [ ] **Compose:** `sendEmail(_:)`, `createDraft(_:)`, `updateDraft(id:_:)`, `deleteDraft(id:)`
- [ ] **Recommendations:** `fetchRecommendations(type:status:accountID:sourceEmailID:cursor:limit:)`, `fetchRecommendationDetail(id:)`, `createRecommendation(_:)`, `updateRecommendationStatus(id:status:)`
- [ ] **Digests:** `fetchDigests(cursor:limit:)`, `fetchLatestDigest(type:)`, `fetchDigest(id:)`
- [ ] **Accounts:** `fetchAccounts()`, `fetchAccount(id:)`
- [ ] **VIP:** `fetchVIPSenders()`, `addVIPSender(email:name:)`, `removeVIPSender(id:)`
- [ ] **Health:** `fetchHealth()` (does not require auth)
- [ ] GET requests use exponential backoff retry (max 3 attempts, 1s base delay)
- [ ] POST/PATCH/PUT/DELETE requests do NOT retry automatically
- [ ] Response errors are mapped to `APIError` with appropriate detail
- [ ] HTTP 401 maps to `APIError.unauthorized`
- [ ] HTTP 404 maps to `APIError.notFound`
- [ ] HTTP 409 maps to `APIError.conflict`
- [ ] `ServerDiscovery` actor tries configured URL, then local, then Tailscale IP
- [ ] `updateBaseURL(_:)` allows changing the server URL at runtime
- [ ] Unit tests with `URLProtocolMock` verify all endpoints, retry behavior, and error mapping
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.4: EmailClientKit -- WebSocket Manager

**Complexity:** L
**Branch:** `macos/foundation`
**Dependencies:** M-1.2

**Description:**
Create the `WebSocketManager` actor that maintains a persistent WebSocket connection to the server. Decode incoming events into the `WebSocketEvent` discriminated union. Expose events as an `AsyncStream`. Handle reconnection with exponential backoff. Send periodic pings for keep-alive.

**Files to create:**
- `Packages/EmailClientKit/Sources/EmailClientKit/Networking/WebSocketManager.swift`
- Tests for WebSocket event decoding and reconnection logic

**Acceptance Criteria:**
- [ ] `WebSocketManager` is an `actor`
- [ ] `connect(baseURL:token:)` establishes WebSocket at `/api/v1/ws?token=<token>`
- [ ] Converts `http://` to `ws://` and `https://` to `wss://` in the URL scheme
- [ ] `disconnect()` cleanly closes the connection
- [ ] `events` property exposes `AsyncStream<WebSocketEvent>`
- [ ] Incoming JSON messages are decoded using `JSONDecoder.apiDecoder` into `WebSocketEvent`
- [ ] Unknown event types are logged and skipped (forward compatibility)
- [ ] Connection loss yields a `.connectionLost` synthetic event on the stream
- [ ] Automatic reconnection with exponential backoff: 1s, 2s, 4s, ... up to 60s max
- [ ] Reconnection resets backoff delay on successful connection
- [ ] `sendPing()` sends a WebSocket ping frame
- [ ] Ping sent every 30 seconds via an internal timer task
- [ ] Pong timeout of 10 seconds triggers reconnection
- [ ] Thread-safe connection state tracking (`isConnected` property)
- [ ] Unit tests verify event decoding for all 11 event types plus connectionLost
- [ ] Unit tests verify reconnection backoff calculation
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.5: EmailClientKit -- Local Cache Layer

**Complexity:** M
**Branch:** `macos/foundation`
**Dependencies:** M-1.2

**Description:**
Create the `LocalCache` actor for offline data persistence. Uses `FileManager` with `Codable` JSON serialization to the app's caches directory. Cache email lists per view, email detail bodies (LRU, max 100), recommendations, latest digest, and account list.

**Files to create:**
- `Packages/EmailClientKit/Sources/EmailClientKit/Cache/LocalCache.swift`
- `Packages/EmailClientKit/Sources/EmailClientKit/Cache/OfflineActionQueue.swift`
- Tests for cache read/write and action queue

**Acceptance Criteria:**
- [ ] `LocalCache` is an `actor` for thread-safe access
- [ ] `save<T: Encodable>(_:key:)` serializes to JSON file in caches directory
- [ ] `load<T: Decodable>(_:key:)` deserializes from JSON file, returns nil if not found
- [ ] `clear(key:)` removes a cached file
- [ ] `clearAll()` removes all cached files
- [ ] Email detail cache uses LRU eviction at 100 items
- [ ] Cache directory is `<AppCaches>/EmailClientCache/`
- [ ] `OfflineActionQueue` actor queues user actions (archive, snooze, reclassify, markRead, updateRecommendationStatus)
- [ ] `OfflineActionQueue.enqueue(_:)` persists queue to disk
- [ ] `OfflineActionQueue.flush(apiClient:)` replays actions in order, removing each on success
- [ ] Flush stops on first failure (preserves action ordering)
- [ ] `OfflineActionQueue.pendingCount` returns the number of queued actions
- [ ] Unit tests verify cache round-trip, LRU eviction, action queue persist/flush
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.6: App Shell -- NavigationSplitView and Sidebar

**Complexity:** L
**Branch:** `macos/foundation`
**Dependencies:** M-1.3, M-1.4

**Description:**
Create the macOS app shell with a three-column NavigationSplitView. Implement the sidebar with all 5 views plus Daily Digest entry. Create the `AppState`, `AppCoordinator`, `EmailStore`, `RecommendationStore`, and `DigestStore` observable classes. Wire up server discovery, initial data fetch, and WebSocket event routing. The sidebar should show badge counts for Action Queue and Filtered, a "NEW" indicator for Digest, and no badge for Reading Queue.

**Files to create:**
- `macOS/ContentView.swift` (NavigationSplitView shell)
- `macOS/Views/Sidebar/SidebarView.swift`
- `macOS/Views/Sidebar/SidebarRow.swift`
- `macOS/Stores/AppState.swift`
- `macOS/Stores/AppCoordinator.swift`
- `macOS/Stores/EmailStore.swift`
- `macOS/Stores/RecommendationStore.swift`
- `macOS/Stores/DigestStore.swift`
- `macOS/EmailApp_macOS.swift` (updated App entry point)

**Acceptance Criteria:**
- [ ] App launches with a three-column NavigationSplitView
- [ ] Sidebar shows: Action Queue, Reading Queue, Recommendations, Filtered, All Inboxes, separator, Daily Digest
- [ ] Sidebar uses Liquid Glass effect (`.glassEffect(.regular)` on sidebar column)
- [ ] Sidebar column width: min 180pt, ideal 220pt, max 260pt
- [ ] Action Queue row shows badge count from `EmailStore`
- [ ] Filtered row shows badge count (uncertain items with confidence < 0.80)
- [ ] Reading Queue row has NO badge (per design-system.md, ADHD-friendly)
- [ ] Daily Digest row shows "NEW" indicator when unread digest available
- [ ] Clicking a sidebar row updates `AppState.selectedView` and the content column switches
- [ ] Content column shows placeholder text per view ("Action Queue view coming soon", etc.)
- [ ] Detail column shows empty state: `envelope.open` icon + "Select an email to read it."
- [ ] `AppCoordinator` starts server discovery, connects API client, connects WebSocket
- [ ] `AppCoordinator.startEventRouting()` routes WebSocket events to stores on `@MainActor`
- [ ] `EmailStore` has arrays for actionQueue, readingQueue, filtered, allInboxes
- [ ] `EmailStore.handleEvent(_:)` inserts/updates/removes emails per event type
- [ ] `RecommendationStore.handleEvent(_:)` handles recommendation events
- [ ] `DigestStore.handleEvent(_:)` handles digest events
- [ ] Stores are injected into the environment for all views
- [ ] App performs initial data fetch on launch (accounts, email counts)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-1.7: Design Tokens and Shared Components

**Complexity:** M
**Branch:** `macos/foundation`
**Dependencies:** M-1.6

**Description:**
Implement the design system tokens (colors, spacing) and shared UI components from the design-system.md spec. These components are used by all views in Phase 2 and Phase 3.

**Files to create:**
- `macOS/Views/Shared/DesignTokens.swift` (Color extensions, spacing constants)
- `macOS/Views/Shared/AccountDot.swift`
- `macOS/Views/Shared/BadgeView.swift`
- `macOS/Views/Shared/SnoozeCountBadge.swift`
- `macOS/Views/Shared/OfflineBanner.swift`
- `macOS/Views/Shared/UndoToast.swift`
- `macOS/Views/Shared/EmptyStateView.swift`
- `macOS/Views/Shared/AccountFilterControl.swift`

**Acceptance Criteria:**
- [ ] `Color.accountWork` = #3B82F6 (light) / #60A5FA (dark)
- [ ] `Color.accountPersonal1` = #22C55E (light) / #4ADE80 (dark)
- [ ] `Color.accountPersonal2` = #F97316 (light) / #FB923C (dark)
- [ ] `Color.snooze` = #8B5CF6 (light) / #A78BFA (dark)
- [ ] `Color.newsletter` = #06B6D4 (light) / #22D3EE (dark)
- [ ] `Color.filtered` = #6B7280 (light) / #9CA3AF (dark)
- [ ] `Color.success` = #22C55E (light) / #4ADE80 (dark)
- [ ] Recommendation type colors defined per design-system.md
- [ ] Spacing constants: spaceXS(4), spaceSM(8), spaceMD(12), spaceLG(16), spaceXL(20), space2XL(24), space3XL(32), space4XL(48)
- [ ] `AccountDot`: 8pt circle, color from account, "Account name account" accessibility label
- [ ] `BadgeView`: capsule, 20pt height, context-based color, hidden when count is 0
- [ ] `SnoozeCountBadge`: capsule, Color.snooze at 15% opacity, "snoozed Nx" text, only shown when snoozeCount >= 2
- [ ] `OfflineBanner`: wifi.slash icon, "Offline -- showing cached data", yellow tint background
- [ ] `UndoToast`: appears at bottom of screen, "Email archived" with Undo button, auto-dismisses after 5 seconds
- [ ] `EmptyStateView`: accepts icon, title, subtitle parameters; centered layout with 48pt icon
- [ ] `AccountFilterControl`: segmented control with All / Work (blue dot) / Personal (green dot), glass effect
- [ ] All components render correctly in light and dark mode
- [ ] All components have accessibility labels
- [ ] Preview providers exist for all components
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Phase 2: Core Features

**Goal:** Action Queue and Reading Queue are fully functional with email list, detail view, keyboard navigation, snooze, archive, compose/reply, and real-time updates.

**Dependencies:** All Phase 1 tasks must be complete.

---

### Task M-2.1: Email Row Component

**Complexity:** M
**Branch:** `macos/action-queue`
**Dependencies:** Phase 1 complete

**Description:**
Implement the standard `EmailRow` component per the design-system.md and action-queue.md specs. This is the base row used in Action Queue, Filtered, and All Inboxes (with view-specific variants). Include unread/read styling, account dot, timestamp formatting, snooze indicators, and proper row height (64pt macOS).

**Files to create:**
- `macOS/Views/EmailList/EmailRowView.swift`
- `macOS/Views/EmailList/SnoozeReturnIndicator.swift`

**Acceptance Criteria:**
- [ ] Row height: 64pt
- [ ] Layout: AccountDot leading, sender name + timestamp on first line, subject on second line, snippet on third line
- [ ] Unread: sender in `.headline` (semibold), subject in `.headline` weight
- [ ] Read: sender in `.subheadline` (regular), subject in `.subheadline` weight, reduced opacity
- [ ] Timestamp: relative ("2m", "1h", "Yesterday") using `.caption` style
- [ ] SnoozeReturnIndicator: 2pt purple left border, "Returning" label in `Color.snooze`
- [ ] SnoozeCountBadge shown when snoozeCount >= 2 at trailing edge of snippet line
- [ ] AccountDot shows correct color per account
- [ ] Has attachment indicator (paperclip icon) when hasAttachments is true
- [ ] Row responds to selection state (accent-colored background at 15% opacity)
- [ ] Hover state: `.quaternarySystemFill` background
- [ ] Accessibility: row announces sender, subject, unread status, snooze status
- [ ] Preview provider with sample data
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.2: Action Queue View

**Complexity:** L
**Branch:** `macos/action-queue`
**Dependencies:** M-2.1

**Description:**
Implement the Action Queue content column per the action-queue.md spec. Two sections (RETURNING and NEW), account filter at top, proper ordering, section headers, badge count sync with sidebar.

**Files to create:**
- `macOS/Views/EmailList/ActionQueueView.swift`
- `macOS/Views/EmailList/EmailListView.swift` (generic list that ActionQueue uses)

**Acceptance Criteria:**
- [ ] Content column width: min 280pt, ideal 340pt, max 420pt
- [ ] Account filter control at top of content column
- [ ] When snoozed returns exist: "RETURNING" section header (gray uppercase `.caption`, purple left accent line) followed by returned items sorted by return_at DESC
- [ ] "NEW" section header followed by new items sorted by received_at DESC
- [ ] When no snoozed returns: no section headers, flat list sorted by received_at DESC
- [ ] Account filter applies to both sections
- [ ] Selection state syncs with `AppState.selectedEmailID`
- [ ] Selecting an email triggers detail fetch via `EmailStore.loadDetail(for:)`
- [ ] Empty state: `EmptyStateView` with `tray.and.arrow.down` icon, "No action needed", "Inbox zero! Well done."
- [ ] Loading state: centered ProgressView for first load
- [ ] Real-time updates: new emails animate in, archived emails animate out
- [ ] Badge count in sidebar matches count of unarchived items in action queue
- [ ] Data source: `GET /api/v1/emails?view=action_queue` with cursor pagination
- [ ] Load more on scroll to bottom (infinite scroll)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.3: Email Detail View

**Complexity:** L
**Branch:** `macos/action-queue`
**Dependencies:** M-2.2

**Description:**
Implement the email detail column with header info, WKWebView body rendering, and toolbar actions. This is the standard detail view used by Action Queue, Filtered, and All Inboxes. The Reading Queue has its own reader view.

**Files to create:**
- `macOS/Views/Detail/EmailDetailView.swift`
- `macOS/Views/Detail/EmailWebView.swift` (NSViewRepresentable WKWebView)
- `macOS/Views/Detail/EmailHeaderView.swift`
- `macOS/Views/Detail/DetailToolbar.swift`

**Acceptance Criteria:**
- [ ] **Header**: From, To, Subject, Date, Account (colored dot + name), snooze badge if applicable
- [ ] **Toolbar** (glass effect): Reply, Reply All, Forward, Archive, Snooze, Move, Trash buttons
- [ ] Toolbar buttons use SF Symbols per action-queue.md spec
- [ ] Toolbar buttons use `.glass` button style within a `GlassEffectContainer`
- [ ] **WKWebView**: renders sanitized HTML from server
- [ ] WKWebView disabled JavaScript (`allowsContentJavaScript = false`)
- [ ] WKWebView uses non-persistent data store
- [ ] WKWebView CSP blocks external resources, allows only `data:` and `cid:` images
- [ ] Dark mode CSS injected for email body
- [ ] Links in email open in system browser (NSWorkspace.shared.open)
- [ ] Quoted replies collapsed by default with "Show quoted text" toggle
- [ ] Plain text fallback: monospaced body font with text selection enabled
- [ ] No detail selected: EmptyStateView with `envelope.open` icon, "Select an email to read it."
- [ ] Attachment list shown below header if hasAttachments
- [ ] Mark email as read when detail view appears (via `PATCH /api/v1/emails/{id}` with `is_read: true`)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.4: Keyboard Navigation System

**Complexity:** XL
**Branch:** `macos/action-queue`
**Dependencies:** M-2.2, M-2.3

**Description:**
Implement the full macOS keyboard system per the swift-client-architecture.md and design-system.md specs. Three layers: Commands (Cmd+key, global), onKeyPress (single-key, contextual), and Command Palette (Cmd+K). Implement focus management with FocusCoordinator.

**Files to create:**
- `macOS/Keyboard/FocusCoordinator.swift`
- `macOS/Commands/AppCommands.swift` (menu bar commands)
- `macOS/Views/CommandPalette/CommandPaletteView.swift`
- `macOS/Views/CommandPalette/CommandItem.swift`
- `macOS/Views/CommandPalette/PaletteCommand.swift`

**Acceptance Criteria:**
- [ ] **Layer 1 -- Commands (global, menu bar):**
  - [ ] Cmd+1: Action Queue
  - [ ] Cmd+2: Reading Queue
  - [ ] Cmd+3: Recommendations
  - [ ] Cmd+4: Filtered
  - [ ] Cmd+5: All Inboxes
  - [ ] Cmd+D: Daily Digest
  - [ ] Cmd+Shift+1: Work accounts only
  - [ ] Cmd+Shift+2: Personal accounts only
  - [ ] Cmd+Shift+3: All accounts
  - [ ] Cmd+N: New compose window
  - [ ] Cmd+Enter: Send email (compose only)
- [ ] **Layer 2 -- onKeyPress (contextual, when list has focus):**
  - [ ] J: navigate down in email list
  - [ ] K: navigate up in email list
  - [ ] Enter: open selected email in detail
  - [ ] Escape: return focus to list from detail, or dismiss overlays
  - [ ] R: reply
  - [ ] A: reply all
  - [ ] F: forward
  - [ ] E: archive with undo toast
  - [ ] S: snooze (opens picker)
  - [ ] M: move/reclassify
  - [ ] #: trash
  - [ ] U: toggle read/unread
  - [ ] /: focus search field
  - [ ] ?: show shortcut help overlay
  - [ ] Tab: cycle focus (sidebar -> list -> detail)
- [ ] **Layer 3 -- Command Palette (Cmd+K):**
  - [ ] Floating overlay with fuzzy search
  - [ ] Glass background (`.ultraThinMaterial`)
  - [ ] 500pt width, max 400pt results height
  - [ ] Search field auto-focused on open
  - [ ] Results show: icon, command name, keyboard shortcut hint
  - [ ] Arrow keys navigate results, Enter executes, Escape dismisses
  - [ ] Commands include all view switches, email actions, compose, snooze, account filters
- [ ] **Focus Management:**
  - [ ] `FocusCoordinator` tracks active focus area: sidebar, emailList, emailDetail, composeBody, searchField, commandPalette, snoozePicker
  - [ ] Single-key shortcuts (J, K, R, S, E) do NOT fire when text input has focus
  - [ ] Cmd+key shortcuts work regardless of focus
  - [ ] Tab cycles through sidebar -> list -> detail
  - [ ] Escape returns focus from detail/compose/search to list
- [ ] All shortcuts appear in the menu bar (discoverability)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.5: Snooze Picker

**Complexity:** M
**Branch:** `macos/action-queue`
**Dependencies:** M-2.3

**Description:**
Implement the snooze picker popover per the design-system.md SnoozePicker spec. Opens from the toolbar Snooze button or S key. Shows preset options and custom date/time picker.

**Files to create:**
- `macOS/Views/Snooze/SnoozePickerView.swift`
- `macOS/Views/Snooze/CustomSnoozePicker.swift`
- `macOS/Views/Snooze/SnoozeOption.swift`

**Acceptance Criteria:**
- [ ] Appears as a popover from the Snooze toolbar button (or popover anchored to keyboard focus)
- [ ] Uses glass effect background (`.glassEffect(.regular)`)
- [ ] Purple tint (`Color.snooze`)
- [ ] Preset options: "2 Hours" (with computed time), "Tomorrow 9am" (with date), "Next Week" (Monday 9am, with date)
- [ ] Each preset shows the computed target time as secondary text
- [ ] "Pick a Date & Time" opens a custom DatePicker sheet
- [ ] Custom picker: graphical DatePicker, date must be in the future
- [ ] Selecting a preset or custom time calls `EmailStore.snooze(_:until:)` -> `POST /api/v1/emails/{id}/snooze`
- [ ] Snooze picker dismisses after selection
- [ ] Email disappears from list with animation after snooze
- [ ] UndoToast shows "Email snoozed until [time]" with Undo button
- [ ] Undo calls `DELETE /api/v1/emails/{id}/snooze`
- [ ] Keyboard: S opens picker, 1/2/3 select presets, C opens custom, Escape closes
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.6: Compose and Reply

**Complexity:** L
**Branch:** `macos/compose`
**Dependencies:** M-2.3

**Description:**
Implement the compose window for new emails, reply, reply all, and forward. Separate window on macOS (per swift-client-architecture.md). Plain text body for v1. Account picker defaults to the receiving account for replies. Auto-save drafts every 30 seconds.

**Files to create:**
- `macOS/Stores/ComposeStore.swift`
- `macOS/Views/Compose/ComposeView.swift`
- `macOS/Views/Compose/AccountPicker.swift`
- `macOS/Views/Compose/RecipientField.swift`

**Acceptance Criteria:**
- [ ] Compose opens as separate window via `Window("Compose", id: "compose")` scene
- [ ] Window default size: 600 x 500pt
- [ ] Cmd+N opens new compose; R/A/F from email detail prepopulates
- [ ] Layout: From (account picker), To, CC (collapsed by default, expandable), Subject, Body (TextEditor)
- [ ] Account picker shows colored dot + email address for each account
- [ ] Reply: sets To to original sender, Subject to "Re: [original]", quotes original body, sets `inReplyTo`
- [ ] Reply All: sets To to original sender, CC to all other recipients, same subject/quote
- [ ] Forward: sets Subject to "Fwd: [original]", includes original body below separator
- [ ] Focus: new compose focuses To field; reply/reply-all focuses Body field
- [ ] Send: Cmd+Enter, calls `POST /api/v1/compose/send`, closes window on success
- [ ] Discard: Escape with confirmation if body is non-empty
- [ ] Auto-save: draft saved every 30 seconds via `POST /api/v1/compose/drafts` (first save) or `PUT /api/v1/compose/drafts/{id}` (subsequent)
- [ ] Error: shows inline error if send fails
- [ ] ComposeStore manages draft state, prepares reply/forward context
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.7: Reading Queue View

**Complexity:** L
**Branch:** `macos/reading-queue`
**Dependencies:** M-2.1, M-2.3

**Description:**
Implement the Reading Queue content and detail columns per the reading-queue.md spec. Newsletter list with source name as primary text, reader-optimized detail view with comfortable typography, recommendation extraction footer, sequential reading mode.

**Files to create:**
- `macOS/Views/EmailList/ReadingQueueView.swift`
- `macOS/Views/EmailList/NewsletterRowView.swift`
- `macOS/Views/Reading/NewsletterReaderView.swift`
- `macOS/Views/Reading/NewsletterWebView.swift` (reader-optimized WKWebView)
- `macOS/Views/Reading/RecommendationFooter.swift`

**Acceptance Criteria:**
- [ ] **Newsletter list:**
  - [ ] Source name (newsletter name) as primary text in `.headline`
  - [ ] Subject as secondary text
  - [ ] Snippet as tertiary text
  - [ ] No snooze badges (newsletters are not snoozable)
  - [ ] Subtle read/unread distinction (opacity change, not bold/regular)
  - [ ] Reading progress indicator for partially-read items (trailing edge)
  - [ ] Recommendation extraction badge: star icon + count if recommendations extracted
  - [ ] No section headers (flat list, unread at top, partially-read at bottom)
  - [ ] No sidebar badge count (ADHD-friendly)
- [ ] **Newsletter reader (detail column):**
  - [ ] Reader-optimized WKWebView with: font-size 17px, line-height 1.6, max-width 680px, centered, 24px horizontal padding
  - [ ] Uses `reader_mode=true` parameter when fetching email detail
  - [ ] Header: newsletter name (`.title2` bold), author/source (`.subheadline`), date
  - [ ] Toolbar: Archive (E), Open Original (O), Share -- NO Reply/Forward/Snooze
  - [ ] Recommendations footer: lists extracted recommendations with type icon + title + creator
  - [ ] Tapping a recommendation navigates to Recommendations view filtered by source
  - [ ] "Open original email" link navigates to All Inboxes with this email selected
  - [ ] Progress bar at top (thin, accent color, based on scroll position)
- [ ] **Sequential reading mode:** After archiving (E), detail automatically loads next unread newsletter
- [ ] **J/K navigation:** cycles through newsletters in list, updates reader
- [ ] Data source: `GET /api/v1/emails?view=reading_queue`
- [ ] Empty state: `book.open` icon, "Nothing to read", "Newsletters will appear here"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-2.8: Real-Time Updates Integration

**Complexity:** M
**Branch:** `macos/realtime`
**Dependencies:** M-2.2, M-2.7

**Description:**
Wire WebSocket events to store updates and ensure all views react to real-time changes. New emails appear in lists, archived emails disappear, classification changes move emails between lists, snooze returns appear at top of Action Queue, recommendations appear in store.

**Files to create:**
- No new files; update `AppCoordinator`, `EmailStore`, `RecommendationStore`, `DigestStore`

**Acceptance Criteria:**
- [ ] `email.new`: inserts email into correct store array based on classification, animates into list
- [ ] `email.updated`: updates email in-place in all arrays where it exists (read state, archive state)
- [ ] `email.deleted`: removes email from all arrays
- [ ] `classification.changed`: removes email from old queue array, inserts into new queue array
- [ ] `snooze.created`: removes email from action queue (it is now actively snoozed)
- [ ] `snooze.returned`: inserts email at top of action queue with snooze return indicator
- [ ] `snooze.cancelled`: inserts email back into action queue (re-appears)
- [ ] `recommendation.new`: inserts recommendation at top of recommendations array
- [ ] `recommendation.updated`: updates recommendation in-place
- [ ] `digest.available`: updates latest digest in DigestStore, shows "NEW" in sidebar
- [ ] `account.status`: updates account connection status in AppState
- [ ] OfflineBanner appears when WebSocket connection is lost
- [ ] OfflineBanner disappears when reconnected
- [ ] On reconnection, REST fetch syncs any missed updates
- [ ] Sidebar badge counts update reactively
- [ ] All list animations use SwiftUI implicit animations (smooth insert/remove)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Phase 3: Advanced Features

**Goal:** All 5 views fully functional, Daily Digest view, compose/reply, offline caching, search, and Liquid Glass polish.

**Dependencies:** All Phase 2 tasks must be complete.

---

### Task M-3.1: Recommendations View

**Complexity:** L
**Branch:** `macos/recommendations`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Recommendations content and detail columns per the recommendations.md spec. Card-based layout with type filter pills, status filter, inline action buttons, and detail view with duplicate sources.

**Files to create:**
- `macOS/Views/Recommendations/RecommendationListView.swift`
- `macOS/Views/Recommendations/RecommendationCard.swift`
- `macOS/Views/Recommendations/RecommendationDetailView.swift`
- `macOS/Views/Recommendations/RecommendationFilterBar.swift`
- `macOS/Views/Recommendations/TypeBadge.swift`

**Acceptance Criteria:**
- [ ] **Type filter bar:** horizontally scrolling pills: All, Books, Movies/TV, Music, Articles, Podcasts, Other
- [ ] Active pill tinted with type color token (purple for Books, red for Movies, etc.)
- [ ] Each pill shows SF Symbol icon + label
- [ ] **Status filter:** segmented picker: New (default, with count), Saved, Done, Dismissed, All
- [ ] **Recommendation cards (120pt height):**
  - [ ] Type icon (colored, 20pt) leading
  - [ ] Title in `.headline`, bold
  - [ ] Creator in `.subheadline`, secondary color
  - [ ] Context snippet in `.callout`, italic, max 2 lines
  - [ ] Source + date in `.caption`, tertiary color
  - [ ] Duplicate badge: "Rec'd by N sources" in `.caption`, `Color.accentColor`
  - [ ] Action buttons: Save (bookmark), Done (checkmark), Dismiss (X)
  - [ ] Card background: system grouped background, 12pt corner radius, subtle shadow
  - [ ] Selected card: accent-colored left border (3pt)
- [ ] **Detail view:**
  - [ ] Large type icon, full title, creator, type label, status
  - [ ] Full context snippet (not truncated)
  - [ ] All duplicate sources listed with newsletter name, date, and context
  - [ ] "Open source newsletter" link navigates to Reading Queue
  - [ ] "Open in browser" link for articles/podcasts (opens system browser)
  - [ ] Toolbar: Save, Done, Dismiss, Open Source
- [ ] **Keyboard:** S (Save), D (Done), X (Dismiss) on selected card, J/K to navigate
- [ ] Status changes are optimistic with undo toast
- [ ] Data source: `GET /api/v1/recommendations`
- [ ] Empty state: `star` icon, "No recommendations yet", "Recommendations will appear as newsletters are processed"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-3.2: Filtered View

**Complexity:** L
**Branch:** `macos/filtered`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Filtered view per the filtered.md spec. Two sections (NEEDS REVIEW and OTHER), confidence scores, days remaining, rescue actions, and classification reasoning.

**Files to create:**
- `macOS/Views/EmailList/FilteredView.swift`
- `macOS/Views/EmailList/FilteredRowView.swift`
- `macOS/Views/Detail/FilteredDetailView.swift`
- `macOS/Views/Detail/RescuePicker.swift`

**Acceptance Criteria:**
- [ ] **Info banner:** sticky at top, "Items auto-delete after 14 days", `info.circle` icon, `Color.filtered` at 10% opacity
- [ ] **NEEDS REVIEW section:** shown when borderline items exist (confidence < 0.80), yellow-tinted header with count
- [ ] **OTHER section:** standard filtered items
- [ ] **Filtered row (72pt height):**
  - [ ] Full sender email (not name) as primary identifier
  - [ ] Confidence score in `.caption`, color varies: < 80% = `Color.snooze`, >= 80% = `Color.filtered`
  - [ ] Days remaining label: "14d left", "7d left", etc. in `.caption2`
  - [ ] Borderline indicator: "!!" icon in `Color.snooze` for NEEDS REVIEW items
- [ ] **Detail view:**
  - [ ] Standard email header + body
  - [ ] Classification info: "Filtered (Spam/Marketing)", confidence %, AI reason
  - [ ] **Rescue actions (prominent):**
    - [ ] "Not Spam -- Move to Action Queue" (key 1)
    - [ ] "Not Spam -- Move to Reading Queue" (key 2)
    - [ ] "Not Spam -- Move to All Inboxes" (key 3)
    - [ ] "This IS Spam" (key C) -- confirms classification
    - [ ] "Delete Now" (key #) -- permanent delete
  - [ ] Toolbar: Not Spam (N, opens rescue picker), Confirm Spam (C)
- [ ] Rescue/confirm sends training signal via `POST /api/v1/emails/{id}/reclassify` with `confirm` parameter
- [ ] Rescued email disappears from Filtered, appears in target queue
- [ ] Undo toast for rescue and confirm actions
- [ ] Data source: `GET /api/v1/emails?view=filtered`
- [ ] Empty state: `shield.checkmark` icon, "All clear", "No suspicious emails. The filter is working."
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-3.3: All Inboxes View

**Complexity:** M
**Branch:** `macos/all-inboxes`
**Dependencies:** Phase 2 complete

**Description:**
Implement the All Inboxes view per the all-inboxes.md spec. Flat chronological list with classification badges, search bar, full action set.

**Files to create:**
- `macOS/Views/EmailList/AllInboxesView.swift`
- `macOS/Views/EmailList/ClassificationBadge.swift`
- `macOS/Views/EmailList/SearchBar.swift`

**Acceptance Criteria:**
- [ ] **Flat chronological list:** all emails by received_at DESC, no sections or grouping
- [ ] **Classification badge** on each row: capsule pill, `.caption2` semibold white text
  - [ ] Action Required: `Color.accentColor` background
  - [ ] Newsletter: `Color.newsletter` background
  - [ ] Transactional: `Color.textTertiary` background (muted gray)
  - [ ] Filtered: `Color.filtered` background
  - [ ] Trailing edge of snippet line
  - [ ] Abbreviation on narrow screens: "Action Req.", "Trans.", "News.", "Filt."
- [ ] **Search bar:** sticky at top, always visible, magnifying glass icon, "Search all email..." placeholder
  - [ ] "/" focuses search from list view
  - [ ] Search-as-you-type with 300ms debounce
  - [ ] Minimum 2 characters
  - [ ] API: `GET /api/v1/search?q={query}&account_id={filter}`
  - [ ] Results replace email list with search results
  - [ ] Search results show query terms bolded in subject and snippet
  - [ ] Clear (X) restores full list
  - [ ] Escape: clear search and return focus to list
- [ ] **Full action set** in detail view regardless of classification (Reply, Reply All, Forward, Archive, Snooze, Move, Trash)
- [ ] **V key:** "View in original queue" -- navigates to classified queue with email selected
- [ ] Archived emails visible but with slightly dimmed styling
- [ ] No sidebar badge count
- [ ] Real-time updates: reacts to all email events
- [ ] Data source: `GET /api/v1/emails?view=all_inboxes`
- [ ] Empty state: `tray` icon, "No emails", "Your inbox is empty"
- [ ] Empty search: `magnifyingglass` icon, "No results", "No emails match '[query]'"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-3.4: Daily Digest View

**Complexity:** L
**Branch:** `macos/digest`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Daily Digest view per the daily-digest.md spec. Morning and evening digest sections, inline actions on borderline items, date picker for historical digests, training period behavior.

**Files to create:**
- `macOS/Views/Digest/DigestView.swift`
- `macOS/Views/Digest/DigestSectionView.swift`
- `macOS/Views/Digest/ActionQueueSummarySection.swift`
- `macOS/Views/Digest/ReturningTodaySection.swift`
- `macOS/Views/Digest/ReadingQueueSummarySection.swift`
- `macOS/Views/Digest/BorderlineItemsSection.swift`
- `macOS/Views/Digest/NotableTransactionalSection.swift`
- `macOS/Views/Digest/TodayStatsSection.swift`
- `macOS/Views/Digest/StillPendingSection.swift`
- `macOS/Views/Digest/NewslettersTodaySection.swift`
- `macOS/Views/Digest/SnoozeNudgesSection.swift`
- `macOS/Views/Digest/DigestDatePicker.swift`

**Acceptance Criteria:**
- [ ] Uses content column width (no detail column needed, or detail shows email if tapped)
- [ ] **Morning sections (in order):** Action Queue Summary, Returning Today, Reading Queue Summary, Might Not Be Spam (borderline), Notable Transactional
- [ ] **Evening sections (in order):** Today's Stats, Still Pending, Newsletters Today, Snooze Nudges, Notable Transactional
- [ ] Sections with no data are omitted (hidden)
- [ ] **Action Queue Summary:** count in `.title3`, per-account breakdown with AccountDots, "View Action Queue" link (navigates via Cmd+1)
- [ ] **Returning Today:** purple dot per item, subject + sender, return time, snooze count
- [ ] **Reading Queue Summary:** count, "View Reading Queue" link
- [ ] **Borderline Items:** sender, subject, confidence %, [Not Spam] and [Spam] inline buttons
  - [ ] Not Spam opens rescue picker (move to Action Queue / Reading Queue / All Inboxes)
  - [ ] Spam confirms classification
  - [ ] Training period: shows 5 items (first 2 weeks), then 3
- [ ] **Notable Transactional:** packages arriving, large charges (> $100)
- [ ] **Today's Stats (evening):** emails sent count, emails archived count
- [ ] **Still Pending (evening):** count of unarchived action_required emails
- [ ] **Newsletters Today (evening):** list of newsletters with name + subject
- [ ] **Snooze Nudges (evening):** emails snoozed 3+ times with count and days since first snooze
- [ ] **Date picker:** bottom of digest, allows navigating to previous digests
- [ ] "NEW" indicator in sidebar clears when digest is viewed
- [ ] Section headers: gray uppercase `.caption`, 1pt separator below each section
- [ ] Data source: `GET /api/v1/digests/latest` and `GET /api/v1/digests/{id}`
- [ ] Empty state: `newspaper` icon, "No digest yet", "Your first digest will generate at 6:00 AM"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-3.5: Offline Caching Integration

**Complexity:** M
**Branch:** `macos/offline`
**Dependencies:** Phase 2 complete

**Description:**
Wire the LocalCache and OfflineActionQueue into the app flow. On launch, load cached data immediately, then fetch from server. When offline, show cached data and queue user actions. On reconnection, flush action queue and sync.

**Files to create:**
- No new files; update `AppCoordinator`, `EmailStore`, `RecommendationStore`, `DigestStore`

**Acceptance Criteria:**
- [ ] On app launch: load cached email lists, recommendations, digest, accounts from LocalCache immediately
- [ ] Views display cached data instantly while server fetch is in progress
- [ ] After server fetch completes: update stores and update cache
- [ ] When server is unreachable: OfflineBanner appears
- [ ] User actions while offline are queued in OfflineActionQueue (archive, snooze, reclassify, markRead, recommendation status)
- [ ] Optimistic UI updates still apply while offline (email disappears on archive, etc.)
- [ ] On reconnection: OfflineActionQueue.flush() replays actions in order
- [ ] On reconnection: REST fetch syncs missed updates
- [ ] On reconnection: OfflineBanner disappears
- [ ] Reconnection check every 15 seconds when offline
- [ ] Cache is updated after every successful REST fetch
- [ ] Pending action count shown in OfflineBanner ("3 actions pending sync")
- [ ] If flush fails partway: remaining actions stay queued, user notified
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task M-3.6: Liquid Glass Polish and Menu Bar Extra

**Complexity:** M
**Branch:** `macos/polish`
**Dependencies:** All other Phase 3 tasks

**Description:**
Apply Liquid Glass effects to all appropriate surfaces per the design-system.md spec. Implement the MenuBarExtra with action queue count and connection status. Final visual polish pass.

**Files to create:**
- `macOS/Views/Shared/GlassEffects.swift` (view modifiers for consistent glass application)
- `macOS/MenuBarView.swift`
- Update all toolbar and chrome views with glass effects

**Acceptance Criteria:**
- [ ] **Glass surfaces:** sidebar, toolbar, snooze picker, command palette, account filter control, floating action buttons
- [ ] **No glass on content:** email rows, email body, recommendation cards, digest sections, compose text area, search results, empty states
- [ ] Toolbar action groups (Reply, Archive, Snooze) morph as connected group within `GlassEffectContainer`
- [ ] Snooze picker buttons morph within shared container
- [ ] Account filter segmented control morphs between states
- [ ] **MenuBarExtra:**
  - [ ] Shows envelope icon in menu bar
  - [ ] Menu content: "Action Queue: N", divider, "New Email" (Cmd+N), divider, connection status
  - [ ] Uses `.menuBarExtraStyle(.menu)`
- [ ] Sidebar glass tints with account color when filtered to single account
- [ ] Glass effects respect light/dark mode
- [ ] All animations are smooth (no jank on glass transitions)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Summary

| Phase | Task Count | Key Deliverables |
|-------|-----------|-----------------|
| Phase 1 | 7 tasks | Xcode project, EmailClientKit (models + API + WebSocket + cache), app shell, sidebar, design tokens |
| Phase 2 | 8 tasks | Action Queue, Reading Queue, email detail, keyboard system, snooze, compose, real-time updates |
| Phase 3 | 6 tasks | Recommendations, Filtered, All Inboxes, Daily Digest, offline caching, Liquid Glass polish |
| **Total** | **21 tasks** | |

### Dependency Graph (Critical Path)

```
M-1.1 -> M-1.2 -> M-1.3 (API client)
M-1.1 -> M-1.2 -> M-1.4 (WebSocket)
M-1.1 -> M-1.2 -> M-1.5 (cache)
M-1.3 + M-1.4 -> M-1.6 (app shell)
M-1.6 -> M-1.7 (design tokens)

Phase 1 -> M-2.1 (email row)
M-2.1 -> M-2.2 (action queue view)
M-2.2 -> M-2.3 (email detail)
M-2.2 + M-2.3 -> M-2.4 (keyboard system)
M-2.3 -> M-2.5 (snooze picker)
M-2.3 -> M-2.6 (compose)
M-2.1 + M-2.3 -> M-2.7 (reading queue)
M-2.2 + M-2.7 -> M-2.8 (real-time updates)

Phase 2 -> M-3.1 (recommendations)
Phase 2 -> M-3.2 (filtered)
Phase 2 -> M-3.3 (all inboxes)
Phase 2 -> M-3.4 (daily digest)
Phase 2 -> M-3.5 (offline caching)
All Phase 3 -> M-3.6 (liquid glass polish)
```
