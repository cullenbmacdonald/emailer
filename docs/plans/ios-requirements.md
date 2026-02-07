# iOS App Implementation Requirements

> Implementation task breakdown for the iOS SwiftUI app. Each task has a unique ID (I-N.N), acceptance criteria, dependencies, and complexity estimate. Agents should complete tasks in order within each phase, respecting dependencies.
>
> **Reference documents:**
> - [API Specification](/docs/plans/api-spec.yaml) -- canonical endpoint and schema definitions
> - [API Guide](/docs/plans/api-guide.md) -- human-readable API patterns and examples
> - [Design System](/docs/plans/ui-ux/design-system.md) -- shared tokens, components, patterns
> - [Action Queue Spec](/docs/plans/ui-ux/action-queue.md) -- iOS layout, swipe actions, gestures
> - [Reading Queue Spec](/docs/plans/ui-ux/reading-queue.md) -- iOS reader view
> - [Recommendations Spec](/docs/plans/ui-ux/recommendations.md) -- iOS card layout
> - [Filtered Spec](/docs/plans/ui-ux/filtered.md) -- iOS filtered list
> - [All Inboxes Spec](/docs/plans/ui-ux/all-inboxes.md) -- iOS search, classification badges
> - [Daily Digest Spec](/docs/plans/ui-ux/daily-digest.md) -- iOS sheet presentation
> - [Swift Client Architecture Brainstorm](/docs/brainstorms/swift-client-architecture.md) -- TabView, swipe gestures, iPad adaptation
> - [MASTER-PLAN.md](/docs/plans/MASTER-PLAN.md) -- phased delivery plan
>
> **Tech stack:**
> - Swift 6.0+ with strict concurrency
> - SwiftUI (iOS 18 minimum deployment target)
> - `@Observable` for state management
> - URLSession async/await for networking (no external dependencies)
> - WKWebView (UIViewRepresentable) for email HTML rendering
> - Shared `EmailClientKit` Swift Package (created by macOS agent, imported here)
>
> **Important:** The iOS app imports the shared `EmailClientKit` package created in the macOS requirements (M-1.1 through M-1.5). The models, API client, WebSocket manager, and cache layer are already implemented there. The iOS app provides platform-specific UI only.
>
> **Project structure:**
> - `Packages/EmailClientKit/` -- shared Swift package (already exists from macOS work)
> - `iOS/` -- iOS app target (this document)
> - `macOS/` -- macOS app target (separate requirements doc)

---

## Phase 1: Foundation

**Goal:** iOS app compiles, displays a TabView with all tabs, connects to the server, and has platform-specific design tokens and shared components.

---

### Task I-1.1: iOS App Target and Project Configuration

**Complexity:** M
**Branch:** `ios/foundation`
**Dependencies:** M-1.1 (Xcode project must exist), M-1.2 (models), M-1.3 (API client)

**Description:**
Configure the iOS app target within the existing Xcode project. The macOS agent creates the project and shared package; this task ensures the iOS target compiles, links to EmailClientKit, and has proper build settings. If the iOS target was created as a placeholder in M-1.1, this task fully configures it. Add iOS-specific SwiftLint rules if needed.

**Files to create/modify:**
- `iOS/EmailApp_iOS.swift` (update App entry point with proper scene)
- `iOS/Info.plist` (or Xcode build settings for iOS-specific configuration)

**Acceptance Criteria:**
- [ ] iOS target compiles for iPhone and iPad simulators
- [ ] iOS target depends on `EmailClientKit` package
- [ ] Deployment target: iOS 18
- [ ] Bundle ID: `com.cullenbmacdonald.emailer.ios`
- [ ] App launches on simulator showing a basic TabView
- [ ] SwiftLint runs against iOS target without errors
- [ ] `make build-ios` works from the Makefile
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-1.2: TabView Shell and Navigation Structure

**Complexity:** L
**Branch:** `ios/foundation`
**Dependencies:** I-1.1

**Description:**
Create the main iOS navigation structure per the design-system.md and swift-client-architecture.md specs. iPhone uses TabView with 4 tabs (Action, Reading, Recs, More). iPad uses NavigationSplitView. Create the AppState, AppCoordinator, and store instances for iOS. Wire up server discovery, initial fetch, and WebSocket.

**Files to create:**
- `iOS/Views/Tabs/MainTabView.swift`
- `iOS/Views/Tabs/MoreView.swift` (contains Filtered, All Inboxes entries)
- `iOS/Views/Sidebar/SidebarView_iOS.swift` (iPad sidebar)
- `iOS/Views/MainView_iPad.swift` (iPad NavigationSplitView)
- `iOS/Stores/AppState_iOS.swift` (extends shared AppState with iOS-specific properties)
- `iOS/Stores/AppCoordinator_iOS.swift` (iOS app coordinator)

**Acceptance Criteria:**
- [ ] **iPhone layout:** TabView with 4 tabs
  - [ ] Tab 1: "Action" with `exclamationmark.circle` icon, badge showing unread count
  - [ ] Tab 2: "Reading" with `book` icon, NO badge (ADHD-friendly)
  - [ ] Tab 3: "Recs" with `star` icon, no badge
  - [ ] Tab 4: "More" with `ellipsis.circle` icon, no badge
- [ ] **More tab** contains a List with: Filtered (with uncertain count badge), All Inboxes, Daily Digest (with "NEW" indicator)
- [ ] Each tab wraps content in a NavigationStack for push navigation
- [ ] **iPad layout:** NavigationSplitView (3-column) with sidebar, content, detail
  - [ ] Sidebar shows all 5 views + Digest (same as macOS sidebar)
  - [ ] Automatically detected via `UIDevice.current.userInterfaceIdiom == .pad`
- [ ] Tab bar uses Liquid Glass (`.regular` variant via standard system tab bar)
- [ ] Navigation bar uses Liquid Glass (standard system behavior)
- [ ] `AppCoordinator_iOS` starts server discovery, connects API client and WebSocket
- [ ] Stores injected into environment for all views
- [ ] Tab selection persists within session (not across app restarts)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-1.3: iOS Design Tokens and Shared Components

**Complexity:** M
**Branch:** `ios/foundation`
**Dependencies:** I-1.2

**Description:**
Implement iOS-specific design tokens and shared components. Many tokens are the same as macOS (defined in EmailClientKit or shared files), but iOS components have different sizing (10pt dots instead of 8pt, 72pt row heights instead of 64pt, etc.) and touch-specific behavior.

**Files to create:**
- `iOS/Views/Shared/DesignTokens_iOS.swift` (iOS-specific sizing overrides)
- `iOS/Views/Shared/AccountDot_iOS.swift`
- `iOS/Views/Shared/BadgeView_iOS.swift`
- `iOS/Views/Shared/SnoozeCountBadge_iOS.swift`
- `iOS/Views/Shared/OfflineBanner_iOS.swift`
- `iOS/Views/Shared/UndoToast_iOS.swift`
- `iOS/Views/Shared/EmptyStateView_iOS.swift`
- `iOS/Views/Shared/AccountFilterMenu_iOS.swift`

**Acceptance Criteria:**
- [ ] Same color tokens as macOS (can be shared from EmailClientKit or duplicated with same values)
- [ ] Spacing tokens same as macOS (4pt grid)
- [ ] **iOS-specific dimensions:**
  - [ ] AccountDot: 10pt diameter (vs 8pt macOS)
  - [ ] Row height (email list): 72pt (vs 64pt macOS)
  - [ ] Snooze badge height: 22pt (vs 20pt macOS)
  - [ ] Row horizontal padding: 16pt (vs 12pt macOS)
  - [ ] Row vertical padding: 10pt (vs 8pt macOS)
- [ ] `AccountDot_iOS`: 10pt circle with account color
- [ ] `BadgeView_iOS`: 22pt height, capsule, same color logic as macOS
- [ ] `SnoozeCountBadge_iOS`: same as macOS but 22pt height
- [ ] `OfflineBanner_iOS`: adapted for iOS safe area, can modify navigation title instead of banner
- [ ] `UndoToast_iOS`: bottom-positioned, swipe to dismiss
- [ ] `EmptyStateView_iOS`: centered, slightly larger icon (56pt vs 48pt)
- [ ] `AccountFilterMenu_iOS`: toolbar menu button with `line.3.horizontal.decrease.circle` icon
  - [ ] Menu items: "All Accounts", divider, each account with colored dot + name
  - [ ] Tapping sets `AppState.accountFilter`
- [ ] All components render correctly in light and dark mode
- [ ] All components have accessibility labels
- [ ] Dynamic Type support (text scales with system font size)
- [ ] Preview providers exist for all components
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Phase 2: Core Features

**Goal:** Action Queue and Reading Queue are fully functional on iPhone with touch-first interactions: swipe actions, pull-to-refresh, long-press context menus, and push navigation to detail views.

**Dependencies:** All Phase 1 tasks must be complete.

---

### Task I-2.1: Email Row Component (iOS)

**Complexity:** M
**Branch:** `ios/action-queue`
**Dependencies:** Phase 1 complete

**Description:**
Implement the iOS email row component. Same data as macOS EmailRow but with iOS-specific sizing (72pt height, 16pt padding) and touch-optimized layout. No hover states. Larger touch targets.

**Files to create:**
- `iOS/Views/EmailList/EmailRowView_iOS.swift`
- `iOS/Views/EmailList/SnoozeReturnIndicator_iOS.swift`

**Acceptance Criteria:**
- [ ] Row height: 72pt
- [ ] Horizontal padding: 16pt
- [ ] Layout: AccountDot leading (10pt), sender + timestamp first line, subject second line, snippet third line
- [ ] Unread: bold sender, `.headline` weight subject
- [ ] Read: regular weight, reduced opacity
- [ ] Timestamp: relative format, `.caption` style
- [ ] SnoozeReturnIndicator: purple left accent, "Returning" label
- [ ] SnoozeCountBadge shown when snoozeCount >= 2
- [ ] Attachment indicator (paperclip) when hasAttachments
- [ ] Accessibility: row announces sender, subject, unread, snooze
- [ ] Dynamic Type: text scales properly, row height adjusts
- [ ] Preview provider with sample data
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.2: Action Queue View (iOS)

**Complexity:** L
**Branch:** `ios/action-queue`
**Dependencies:** I-2.1

**Description:**
Implement the Action Queue list view for iOS per the action-queue.md spec. Tab 1, sections (RETURNING + NEW), swipe actions, long-press context menu, pull-to-refresh, account filter menu.

**Files to create:**
- `iOS/Views/EmailList/ActionQueueView_iOS.swift`
- `iOS/Views/EmailList/EmailListView_iOS.swift` (generic list used by all email views)

**Acceptance Criteria:**
- [ ] Navigation title: "Action Queue"
- [ ] **Account filter:** toolbar menu button (AccountFilterMenu_iOS)
- [ ] **Sections:** RETURNING (when snooze returns exist) and NEW headers, same logic as macOS
- [ ] **Swipe actions (trailing edge):**
  - [ ] Short swipe (~80pt): Toggle read/unread (Color.accentColor)
  - [ ] Full swipe (>160pt): Archive (Color.success)
- [ ] **Swipe actions (leading edge):**
  - [ ] Short swipe: Snooze (Color.snooze) -- opens snooze picker sheet
  - [ ] Full swipe: Trash (Color.destructive)
- [ ] **Long press context menu:** Reply, Reply All, Forward, Archive, Snooze, Move to..., Mark read/unread, Trash
- [ ] **Pull-to-refresh:** `.refreshable` triggers `EmailStore.loadEmails(for: .actionQueue)`
- [ ] **Tap row:** pushes to EmailDetailView_iOS via NavigationLink
- [ ] **Infinite scroll:** load more when scrolled near bottom
- [ ] **Badge:** Tab 1 badge shows unread action queue count
- [ ] Data source: `GET /api/v1/emails?view=action_queue`
- [ ] Empty state: `tray.and.arrow.down` icon, "No action needed", "Inbox zero! Well done." with checkmark animation
- [ ] Loading state: centered ProgressView
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.3: Email Detail View (iOS)

**Complexity:** L
**Branch:** `ios/action-queue`
**Dependencies:** I-2.2

**Description:**
Implement the email detail view pushed via NavigationStack. Email header, WKWebView body rendering (UIViewRepresentable), and toolbar actions. Shared by Action Queue, Filtered, and All Inboxes.

**Files to create:**
- `iOS/Views/Detail/EmailDetailView_iOS.swift`
- `iOS/Views/Detail/EmailWebView_iOS.swift` (UIViewRepresentable WKWebView)
- `iOS/Views/Detail/EmailHeaderView_iOS.swift`

**Acceptance Criteria:**
- [ ] Pushed via NavigationStack (standard iOS back navigation with swipe gesture)
- [ ] **Header:** From, To, Subject, Date, Account (colored dot + name), snooze badge
- [ ] **Toolbar actions (navigation bar):**
  - [ ] Reply (arrow.turn.up.left)
  - [ ] Reply All (arrow.turn.up.left.2)
  - [ ] Forward (arrow.turn.up.right)
  - [ ] Archive (archivebox)
  - [ ] Snooze (clock) -- presents snooze picker sheet
  - [ ] More (...) -- Move, Trash, Mark read/unread
- [ ] **WKWebView (UIViewRepresentable):**
  - [ ] JavaScript disabled
  - [ ] Non-persistent data store
  - [ ] CSP blocks external resources
  - [ ] Dark mode CSS injected
  - [ ] Links open in Safari (UIApplication.shared.open)
  - [ ] Quoted replies collapsed by default
- [ ] Plain text fallback: scrollable Text with `.body` monospaced font
- [ ] Mark as read on appear: `PATCH /api/v1/emails/{id}` with `is_read: true`
- [ ] Attachment list shown below header
- [ ] Archive action pops back to list (animated)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.4: Snooze Picker (iOS)

**Complexity:** M
**Branch:** `ios/action-queue`
**Dependencies:** I-2.3

**Description:**
Implement the snooze picker as a bottom sheet per the design-system.md spec. Presented from swipe action or toolbar button. Medium detent with preset options and custom date picker.

**Files to create:**
- `iOS/Views/Snooze/SnoozePickerView_iOS.swift`
- `iOS/Views/Snooze/CustomSnoozePicker_iOS.swift`

**Acceptance Criteria:**
- [ ] Presented as `.sheet` with `.presentationDetents([.medium])`
- [ ] Drag handle visible at top
- [ ] "Snooze until..." header
- [ ] Preset rows (List style): "2 Hours" with chevron, "Tomorrow 9am" with chevron, "Next Week" with chevron
- [ ] Each preset shows computed target time as secondary text
- [ ] "Custom..." row opens inline DatePicker (`.graphical` style)
- [ ] Custom picker: date must be in the future, Cancel and Snooze buttons
- [ ] Selecting preset calls `EmailStore.snooze(_:until:)` and dismisses sheet
- [ ] Snooze triggers: email removed from list, UndoToast shows
- [ ] Undo calls `DELETE /api/v1/emails/{id}/snooze`
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.5: Compose and Reply (iOS)

**Complexity:** L
**Branch:** `ios/compose`
**Dependencies:** I-2.3

**Description:**
Implement compose as a full-screen sheet on iOS. New email, reply, reply all, forward. Plain text body. Account picker. Auto-save drafts.

**Files to create:**
- `iOS/Stores/ComposeStore_iOS.swift` (or share with macOS if identical)
- `iOS/Views/Compose/ComposeView_iOS.swift`
- `iOS/Views/Compose/AccountPicker_iOS.swift`

**Acceptance Criteria:**
- [ ] Presented as `.sheet` with `.presentationDetents([.large])` (full screen)
- [ ] Navigation bar: Cancel (leading), Send (trailing, prominent)
- [ ] Layout: From (account picker), To, CC (expandable), Subject, Body (TextEditor)
- [ ] Account picker: Picker with colored dot + email address per account
- [ ] Reply: prepopulates To, Subject ("Re: ..."), quotes original, sets inReplyTo
- [ ] Reply All: prepopulates To + CC, same Subject/quote
- [ ] Forward: prepopulates Subject ("Fwd: ..."), includes original body
- [ ] Focus: new compose focuses To; reply focuses Body
- [ ] Send: calls `POST /api/v1/compose/send`, dismisses on success, inline error on failure
- [ ] Cancel: confirmation alert if body is non-empty
- [ ] Auto-save every 30 seconds
- [ ] Keyboard accessory: formatting hints or dismiss keyboard button (optional)
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.6: Reading Queue View (iOS)

**Complexity:** L
**Branch:** `ios/reading-queue`
**Dependencies:** I-2.1, I-2.3

**Description:**
Implement the Reading Queue for iOS per the reading-queue.md spec. Tab 2, newsletter list with source name as primary, reader-optimized detail view, recommendation footer.

**Files to create:**
- `iOS/Views/EmailList/ReadingQueueView_iOS.swift`
- `iOS/Views/EmailList/NewsletterRowView_iOS.swift`
- `iOS/Views/Reading/NewsletterReaderView_iOS.swift`
- `iOS/Views/Reading/NewsletterWebView_iOS.swift` (UIViewRepresentable, reader CSS)
- `iOS/Views/Reading/RecommendationFooter_iOS.swift`

**Acceptance Criteria:**
- [ ] Tab 2 with `book` icon, NO badge
- [ ] **Newsletter list:**
  - [ ] Source name as primary text (`.headline`)
  - [ ] Subject as secondary, snippet as tertiary
  - [ ] No snooze badges
  - [ ] Subtle read/unread distinction (opacity)
  - [ ] Reading progress indicator for partially-read items
  - [ ] Recommendation extraction badge (star + count)
  - [ ] No section headers
- [ ] **Swipe actions:** archive right-full, no snooze (newsletters not snoozable)
- [ ] **Pull-to-refresh**
- [ ] **Newsletter reader (pushed via NavigationStack):**
  - [ ] Reader WKWebView: font-size 17px, line-height 1.6, max-width 680px, 16px horizontal padding (iOS spec)
  - [ ] Uses `reader_mode=true` when fetching detail
  - [ ] Header: newsletter name, author, date
  - [ ] Toolbar: Archive, Open Original, Share
  - [ ] NO Reply/Forward/Snooze buttons
  - [ ] Recommendations footer with type icons and titles
  - [ ] Progress bar at top (thin, accent color)
  - [ ] Keyboard dismiss on scroll
- [ ] Data source: `GET /api/v1/emails?view=reading_queue`
- [ ] Empty state: `book.open` icon, "Nothing to read", "Newsletters will appear here"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-2.7: Real-Time Updates Integration (iOS)

**Complexity:** M
**Branch:** `ios/realtime`
**Dependencies:** I-2.2, I-2.6

**Description:**
Wire WebSocket events to iOS stores and handle iOS-specific lifecycle concerns: background/foreground transitions, WebSocket disconnect on background, reconnect on foreground, local notifications for digest and snooze returns.

**Files to create:**
- No new files; update AppCoordinator_iOS and stores

**Acceptance Criteria:**
- [ ] All WebSocket event routing same as macOS (email.new, email.updated, etc.)
- [ ] **App backgrounded (iOS):** disconnect WebSocket, save last sync timestamp
- [ ] **App foregrounded (iOS):** REST fetch changes since last sync, reconnect WebSocket
- [ ] **ScenePhase** observation via `@Environment(\.scenePhase)` for lifecycle events
- [ ] **Local notifications:**
  - [ ] New digest: "Morning Digest" / "Evening Digest" notification with summary
  - [ ] Snooze return: "Snoozed email returned: [subject]" notification
  - [ ] Notifications require user permission request on first launch
  - [ ] Tapping notification opens app to relevant view
- [ ] OfflineBanner appears when connection is lost, disappears on reconnect
- [ ] Tab badge count updates reactively from store changes
- [ ] List animations smooth on insert/remove
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Phase 3: Advanced Features

**Goal:** All 5 views and Daily Digest fully functional on iPhone and iPad, offline caching, search, and Liquid Glass polish.

**Dependencies:** All Phase 2 tasks must be complete.

---

### Task I-3.1: Recommendations View (iOS)

**Complexity:** L
**Branch:** `ios/recommendations`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Recommendations view for iOS per the recommendations.md spec. Tab 3 (Recs). Card-based layout with type filter, status filter, inline actions, and detail view pushed via NavigationStack.

**Files to create:**
- `iOS/Views/Recommendations/RecommendationListView_iOS.swift`
- `iOS/Views/Recommendations/RecommendationCard_iOS.swift`
- `iOS/Views/Recommendations/RecommendationDetailView_iOS.swift`
- `iOS/Views/Recommendations/RecommendationFilterBar_iOS.swift`
- `iOS/Views/Recommendations/TypeBadge_iOS.swift`

**Acceptance Criteria:**
- [ ] Tab 3 with `star` icon
- [ ] **Type filter bar:** horizontally scrolling pills at top
  - [ ] All, Books, Movies/TV, Music, Articles, Podcasts, Other
  - [ ] Active pill tinted with type color
  - [ ] Each shows SF Symbol + label
- [ ] **Status filter:** segmented control below type filter: New (with count), Saved, Done, Dismissed, All
- [ ] **Cards (LazyVGrid, adaptive columns min 300pt):**
  - [ ] Type icon, Title, Creator, context snippet (max 2 lines), source + date, duplicate badge
  - [ ] Action buttons: Save, Done, Dismiss
  - [ ] Card background: grouped background, 12pt corners, subtle shadow
- [ ] **Tap card:** pushes to detail view via NavigationStack
- [ ] **Detail view:**
  - [ ] Full context, all duplicate sources, toolbar actions
  - [ ] "Open source newsletter" link
  - [ ] "Open in browser" link for articles/podcasts (opens Safari)
- [ ] **Long press context menu on card:** Save, Done, Dismiss
- [ ] **Swipe actions on card:** swipe to save or dismiss
- [ ] Status changes optimistic with undo toast
- [ ] Pull-to-refresh
- [ ] Data source: `GET /api/v1/recommendations`
- [ ] Empty state: `star` icon, "No recommendations yet"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.2: Filtered View (iOS)

**Complexity:** L
**Branch:** `ios/filtered`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Filtered view for iOS per the filtered.md spec. Accessed via More tab. Sections (NEEDS REVIEW, OTHER), confidence scores, rescue actions via swipe and detail.

**Files to create:**
- `iOS/Views/EmailList/FilteredView_iOS.swift`
- `iOS/Views/EmailList/FilteredRowView_iOS.swift`
- `iOS/Views/Detail/FilteredDetailView_iOS.swift`
- `iOS/Views/Detail/RescuePicker_iOS.swift`

**Acceptance Criteria:**
- [ ] Accessed via More tab -> "Filtered" row
- [ ] **Info banner:** top of list, "Items auto-delete after 14 days"
- [ ] **NEEDS REVIEW section:** borderline items (confidence < 0.80), count in header
- [ ] **OTHER section:** standard filtered items
- [ ] **Filtered row (80pt height on iOS):**
  - [ ] Full sender email, subject, snippet
  - [ ] Confidence score (color-coded)
  - [ ] Days remaining label
  - [ ] Borderline indicator for NEEDS REVIEW items
- [ ] **Swipe actions:**
  - [ ] Leading: "Not Spam" (opens rescue action sheet) in `Color.accentColor`
  - [ ] Trailing: "Confirm Spam" in `Color.filtered`, "Delete" in `Color.destructive`
- [ ] **Long press context menu:** Not Spam -> (Action Queue, Reading Queue, All Inboxes), Confirm Spam, Delete
- [ ] **Detail view (pushed):**
  - [ ] Email content + classification info (confidence, AI reason)
  - [ ] Action sheet for rescue: Move to Action Queue, Move to Reading Queue, Move to All Inboxes
  - [ ] Confirm Spam button
  - [ ] Delete Now button
- [ ] Training signal sent on rescue/confirm
- [ ] Pull-to-refresh
- [ ] Data source: `GET /api/v1/emails?view=filtered`
- [ ] Empty state: `shield.checkmark` icon, "All clear"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.3: All Inboxes View (iOS)

**Complexity:** M
**Branch:** `ios/all-inboxes`
**Dependencies:** Phase 2 complete

**Description:**
Implement the All Inboxes view for iOS per the all-inboxes.md spec. Accessed via More tab. Flat chronological list with classification badges and search.

**Files to create:**
- `iOS/Views/EmailList/AllInboxesView_iOS.swift`
- `iOS/Views/EmailList/ClassificationBadge_iOS.swift`

**Acceptance Criteria:**
- [ ] Accessed via More tab -> "All Inboxes" row
- [ ] **Flat chronological list:** all emails by received_at DESC, no grouping
- [ ] **Classification badge** on each row: capsule, `.caption2`, colored per type
  - [ ] Abbreviation on narrow screens: "Action", "News.", "Trans.", "Filt."
- [ ] **Search:** Standard iOS `.searchable` modifier
  - [ ] Pull down to reveal (standard iOS pattern)
  - [ ] Cancel button appears when active
  - [ ] Search-as-you-type with 300ms debounce, minimum 2 characters
  - [ ] API: `GET /api/v1/search?q={query}&account_id={filter}`
  - [ ] Results replace list, query terms bolded
  - [ ] Keyboard dismiss on scroll
- [ ] **Swipe actions:** same as Action Queue (archive, snooze, trash, read/unread)
- [ ] **Long press context menu:** Reply, Reply All, Forward, Archive, Snooze, Move to..., Mark read/unread, Trash
- [ ] Full action set in detail view regardless of classification
- [ ] Account filter via toolbar menu
- [ ] Archived emails visible with dimmed styling
- [ ] Pull-to-refresh
- [ ] Data source: `GET /api/v1/emails?view=all_inboxes`
- [ ] Empty state: `tray` icon, "No emails"
- [ ] Empty search: `magnifyingglass` icon, "No results"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.4: Daily Digest View (iOS)

**Complexity:** L
**Branch:** `ios/digest`
**Dependencies:** Phase 2 complete

**Description:**
Implement the Daily Digest as a sheet presentation on iOS per the daily-digest.md spec. Accessible from a toolbar button in any tab. Morning and evening sections with inline actions.

**Files to create:**
- `iOS/Views/Digest/DigestView_iOS.swift`
- `iOS/Views/Digest/DigestSectionView_iOS.swift`
- `iOS/Views/Digest/ActionQueueSummarySection_iOS.swift`
- `iOS/Views/Digest/ReturningTodaySection_iOS.swift`
- `iOS/Views/Digest/ReadingQueueSummarySection_iOS.swift`
- `iOS/Views/Digest/BorderlineItemsSection_iOS.swift`
- `iOS/Views/Digest/NotableTransactionalSection_iOS.swift`
- `iOS/Views/Digest/TodayStatsSection_iOS.swift`
- `iOS/Views/Digest/StillPendingSection_iOS.swift`
- `iOS/Views/Digest/NewslettersTodaySection_iOS.swift`
- `iOS/Views/Digest/SnoozeNudgesSection_iOS.swift`

**Acceptance Criteria:**
- [ ] Accessible from toolbar button (`newspaper` icon) in any tab's navigation bar
- [ ] Also accessible from More tab -> "Daily Digest" row
- [ ] Presented as `.sheet` with `.presentationDetents([.large])`
- [ ] **Morning sections (in order):** Action Queue Summary, Returning Today, Reading Queue Summary, Might Not Be Spam, Notable Transactional
- [ ] **Evening sections (in order):** Today's Stats, Still Pending, Newsletters Today, Snooze Nudges, Notable Transactional
- [ ] Sections with no data are hidden
- [ ] **Action Queue Summary:** large count, per-account breakdown, "View Action Queue" tappable link (switches to tab 1)
- [ ] **Returning Today:** purple dots, subject + sender, return time, snooze count
- [ ] **Reading Queue Summary:** count, "View Reading Queue" link (switches to tab 2)
- [ ] **Borderline Items:** sender, subject, confidence %, [Not Spam] and [Spam] buttons
  - [ ] Not Spam presents action sheet (Move to Action Queue / Reading Queue / All Inboxes)
  - [ ] Spam confirms classification
- [ ] **Notable Transactional:** packages, large charges
- [ ] **Evening sections:** stats, pending, newsletters, snooze nudges per spec
- [ ] **Date navigation:** swipe left/right or date picker to see previous digests
- [ ] "NEW" indicator in More tab clears when digest is viewed
- [ ] Data source: `GET /api/v1/digests/latest` and `GET /api/v1/digests/{id}`
- [ ] Empty state: `newspaper` icon, "No digest yet"
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.5: Offline Caching Integration (iOS)

**Complexity:** M
**Branch:** `ios/offline`
**Dependencies:** Phase 2 complete

**Description:**
Wire LocalCache and OfflineActionQueue into the iOS app flow. Same logic as macOS but with iOS-specific lifecycle handling (background/foreground, battery considerations).

**Files to create:**
- No new files; update AppCoordinator_iOS and stores

**Acceptance Criteria:**
- [ ] On launch: load cached data from LocalCache immediately, display while fetching
- [ ] After server fetch: update stores and cache
- [ ] When offline: OfflineBanner appears in navigation bar area
- [ ] User actions while offline queued in OfflineActionQueue
- [ ] Optimistic UI updates apply while offline
- [ ] On foreground (from background): check connectivity, flush queue if online, fetch updates
- [ ] Reconnection polling: every 15 seconds when offline
- [ ] On reconnection: flush queue, REST sync, remove OfflineBanner
- [ ] Cache updated after every successful fetch
- [ ] Pending action count visible in OfflineBanner
- [ ] Background task: register for background refresh to periodically check for new digests
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.6: iPad Layout Adaptation

**Complexity:** M
**Branch:** `ios/ipad`
**Dependencies:** All other Phase 3 iOS tasks

**Description:**
Ensure all views work properly on iPad with NavigationSplitView layout. Three-column layout matching macOS behavior. Verify all views render correctly in both compact and regular size classes.

**Files to create:**
- `iOS/Views/MainView_iPad.swift` (update if needed)
- Adaptations to existing views for size class awareness

**Acceptance Criteria:**
- [ ] iPad detects `.pad` idiom and uses NavigationSplitView
- [ ] **Three-column layout:** sidebar (view selector) + content (list) + detail
- [ ] Sidebar shows all 5 views + Daily Digest with badges/indicators
- [ ] Content column shows email list appropriate to selected view
- [ ] Detail column shows email detail or recommendation detail
- [ ] **Split view behavior:**
  - [ ] Portrait: sidebar collapses, content + detail visible
  - [ ] Landscape: all three columns visible
  - [ ] Standard SwiftUI column collapse/expand behavior
- [ ] All views render correctly at iPad sizes (no truncation, proper spacing)
- [ ] Recommendation cards use larger grid columns on iPad (more cards per row)
- [ ] Digest view uses wider content area on iPad
- [ ] Search in All Inboxes works with iPad keyboard
- [ ] Swipe actions work on iPad (same as iPhone)
- [ ] Multitasking: app works in Split View and Slide Over
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

### Task I-3.7: Liquid Glass Polish (iOS)

**Complexity:** S
**Branch:** `ios/polish`
**Dependencies:** All other Phase 3 iOS tasks

**Description:**
Apply Liquid Glass effects to all appropriate iOS surfaces per the design-system.md spec. Final visual polish pass for iOS.

**Files to create:**
- Update existing views with glass effects where specified

**Acceptance Criteria:**
- [ ] **Glass surfaces:** tab bar (system default), navigation bar (system default), snooze picker sheet background, account filter pills
- [ ] **No glass on content:** email rows, email body, recommendation cards, digest sections, compose area
- [ ] Tab bar minimizes on scroll down (`TabBarMinimizeBehavior.onScrollDown`) where available
- [ ] Touch-responsive glass: buttons scale on press, show touch-point illumination
- [ ] Account filter pills use `.glass` button style, active pill tinted with account color
- [ ] Glass effects respect light/dark mode
- [ ] Smooth animations on all glass transitions
- [ ] All tests pass (`swift test`)
- [ ] Linter passes (`swiftlint`)
- [ ] No compiler warnings

---

## Summary

| Phase | Task Count | Key Deliverables |
|-------|-----------|-----------------|
| Phase 1 | 3 tasks | iOS target, TabView shell, design tokens |
| Phase 2 | 7 tasks | Action Queue, Reading Queue, email detail, swipe actions, snooze, compose, real-time |
| Phase 3 | 7 tasks | Recommendations, Filtered, All Inboxes, Daily Digest, offline, iPad, Liquid Glass |
| **Total** | **17 tasks** | |

### Dependency Graph (Critical Path)

```
M-1.1 through M-1.5 must complete first (shared EmailClientKit package)

I-1.1 (requires M-1.1, M-1.2, M-1.3) -> I-1.2 -> I-1.3

Phase 1 iOS -> I-2.1 (email row)
I-2.1 -> I-2.2 (action queue)
I-2.2 -> I-2.3 (email detail)
I-2.3 -> I-2.4 (snooze picker)
I-2.3 -> I-2.5 (compose)
I-2.1 + I-2.3 -> I-2.6 (reading queue)
I-2.2 + I-2.6 -> I-2.7 (real-time updates)

Phase 2 iOS -> I-3.1 (recommendations)
Phase 2 iOS -> I-3.2 (filtered)
Phase 2 iOS -> I-3.3 (all inboxes)
Phase 2 iOS -> I-3.4 (daily digest)
Phase 2 iOS -> I-3.5 (offline caching)
All Phase 3 iOS -> I-3.6 (iPad layout)
All Phase 3 iOS -> I-3.7 (liquid glass polish)
```

### Cross-Platform Dependencies

```
The iOS app depends on the shared EmailClientKit package created by the macOS agent:
- M-1.1: Xcode project with both targets
- M-1.2: Model layer (shared)
- M-1.3: API client (shared)
- M-1.4: WebSocket manager (shared)
- M-1.5: Local cache layer (shared)

The macOS agent should complete M-1.1 through M-1.5 before the iOS agent begins I-1.1.
Alternatively, the iOS agent can begin I-1.1 once M-1.1 and M-1.2 are complete,
and work on iOS-specific components while M-1.3 through M-1.5 finish.
```
