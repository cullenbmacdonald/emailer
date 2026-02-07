# Native App Architecture Brainstorm

Research notes for building a native macOS/iOS email client in Swift/SwiftUI. Covers IMAP libraries, app architecture, keyboard interaction, multi-platform strategy, email rendering, local storage, and background processing.

---

> **⚠️ Architecture Update**: This document was written before the final architecture was decided. The Swift apps are now **thin API consumers** — they do NOT handle IMAP, classification, storage, or background processing. All of that is done by the Go server on the Mac Mini. The SwiftUI patterns, keyboard system design, email rendering approach, and multi-platform strategy in this document remain relevant for the client apps — but sections on IMAP libraries, local storage (GRDB), background daemons, and XPC should be read as historical research. See `swift-client-architecture.md` for the current thin-client design and `go-server-architecture.md` for server-side concerns.

---

## 1. Swift IMAP Libraries

There are three serious options for IMAP in Swift. Each sits at a different level of abstraction and maturity.

### Option A: MailCore2

The longest-standing option. MailCore2 is a C/C++/Objective-C library with Swift bindings that provides a complete IMAP, POP, and SMTP implementation.

**Pros:**
- Battle-tested over many years; used in production by multiple shipping email clients
- Full protocol coverage: IMAP, POP3, SMTP
- Available via Swift Package Manager
- Handles MIME parsing, attachments, character encoding -- all the ugly parts of email
- Extensive community knowledge and StackOverflow answers

**Cons:**
- The underlying C++ codebase is large and difficult to maintain or fork
- Last meaningful update was around 2020; maintenance has been sporadic since
- No native async/await support -- uses an older callback/operation-queue model
- Reported crashes when wrapping operations in Swift async contexts (e.g., calling `.start()` inside an async function)
- Building from source on macOS can be painful due to the C++ dependency chain
- Not designed around Swift concurrency; adding an async/await wrapper is possible but fragile

**Verdict:** Viable if you need something proven right now and are willing to write a wrapper layer. But the lack of active maintenance and the concurrency mismatch make it a risky long-term bet for a new project.

### Option B: SwiftNIO IMAP (apple/swift-nio-imap)

Apple's own IMAP implementation, built on SwiftNIO. Provides low-level IMAP4rev1 parsing and encoding via NIO channel handlers.

**Pros:**
- Built and maintained by Apple (the Swift Server team)
- Pure Swift, no C++ dependencies
- Sits on SwiftNIO, which is the foundation of serious server-side Swift
- Provides IMAPClientHandler and IMAPServerHandler as NIO ChannelHandler objects that plug into a ChannelPipeline
- Thorough protocol coverage with extensive testing
- Good foundation for building a custom, optimized IMAP client

**Cons:**
- This is a *protocol library*, not an email client library -- you get parsing/encoding, not "fetch my inbox"
- The API surface is low-level: you work with NIO channels, promises, and event loops
- Not production-ready by Apple's own admission (described as close but not there yet)
- No built-in MIME parsing, attachment handling, or message body decoding
- Steep learning curve if you are not already familiar with SwiftNIO
- You would need to build significant infrastructure on top: connection management, mailbox operations, message caching, IDLE support, etc.

**Verdict:** The right foundation if you want full control and are willing to invest significant upfront engineering. Not suitable as a plug-and-play solution.

### Option C: SwiftMail (Cocoanetics/SwiftMail)

Released March 2025. A higher-level framework that wraps SwiftNIO IMAP (and SwiftNIO SMTP) into a developer-friendly async/await API using Swift actors.

**Pros:**
- Modern Swift from the ground up: actors, async/await, structured concurrency
- Built on apple/swift-nio-imap, so it inherits the protocol correctness
- Provides `IMAPServer` and `SMTPServer` actor types that encapsulate connection complexity
- Clean API for authentication, email retrieval, and sending
- Includes CLI demo targets (SwiftIMAPCLI, SwiftSMTPCLI) for quick testing
- Comprehensive logging via Swift Log (IMAP_IN, IMAP_OUT, SMTP_IN, SMTP_OUT) viewable in Console.app
- Actively maintained as of 2025

**Cons:**
- Young library -- released March 2025, so limited production track record
- Created originally for LLM agent frameworks (email reading/writing for AI agents), so the API surface may not cover all email client needs out of the box
- Smaller community than MailCore2; fewer resources if you hit edge cases
- May need extension for advanced features (IDLE push, partial fetch, complex search)
- Depends on swift-nio-imap which itself is not yet officially "production ready"

**Verdict:** The most promising option for a new Swift email client. The async/await actor model aligns perfectly with modern Swift concurrency patterns. The risk is youth -- but the foundation (SwiftNIO IMAP) is solid.

### Recommendation

**Start with SwiftMail** for the IMAP layer. It gives the cleanest integration with modern Swift and avoids the C++ baggage of MailCore2. Build a thin abstraction layer (`EmailProvider` protocol) on top so you can swap implementations if SwiftMail hits a wall.

For MIME parsing and message body handling (which SwiftMail may not fully cover), consider supplementing with:
- **SwiftSoup** for HTML parsing of email bodies
- Custom MIME parsing or a lightweight Objective-C bridge if needed

The architecture should look like:

```
EmailProvider (protocol)
    |
    +-- SwiftMailProvider (concrete, uses SwiftMail actors)
    |       |
    |       +-- IMAPServer actor (per account)
    |       +-- SMTPServer actor (per account)
    |
    +-- [Future: alternative provider if needed]
```

Each of the 3 IMAP accounts gets its own `IMAPServer` actor instance, managed by an `AccountManager` that coordinates fetching across all accounts.

---

## 2. SwiftUI App Architecture

### Navigation Structure

The app has a sidebar with 5 views (Action Queue, Reading Queue, Recommendations, Filtered, All Inboxes) plus a Daily Digest. On Mac, this is a classic three-column layout. On iPhone, it collapses to a stack.

**NavigationSplitView is the right choice.** It is Apple's sanctioned component for sidebar-driven navigation and handles the macOS/iPadOS/iOS adaptation automatically.

#### Three-Column Layout (macOS / iPad)

```swift
NavigationSplitView {
    // Column 1: Sidebar -- the 5 views + Digest
    SidebarView(selection: $selectedView)
} content: {
    // Column 2: Message list for the selected view
    MessageListView(view: selectedView, selection: $selectedMessage)
} detail: {
    // Column 3: Message detail / reader
    MessageDetailView(message: selectedMessage)
}
```

On macOS, use `.navigationSplitViewStyle(.balanced)` so the sidebar and list columns share space proportionally. The detail column stays prominent.

On iPad, NavigationSplitView automatically supports the sidebar toggle button and swipe-to-reveal gesture.

On iPhone, the three columns collapse into a NavigationStack -- sidebar becomes the root, tapping a view pushes the message list, tapping a message pushes the detail.

#### Sidebar Content

```swift
enum AppView: String, CaseIterable, Identifiable {
    case actionQueue = "Action Queue"
    case readingQueue = "Reading Queue"
    case recommendations = "Recommendations"
    case filtered = "Filtered"
    case allInboxes = "All Inboxes"
    case dailyDigest = "Daily Digest"

    var id: String { rawValue }
    var icon: String { /* SF Symbol name per view */ }
}
```

The sidebar is a simple `List` with `selection` binding. Each row shows the view name, icon, and unread/count badge.

#### Reading Queue Special Case

The Reading Queue view should use a different detail layout -- more like a reader app (large comfortable typography, minimal chrome) rather than the standard email detail view. Handle this with a conditional in the detail column:

```swift
detail: {
    switch selectedView {
    case .readingQueue:
        NewsletterReaderView(message: selectedMessage)
    case .recommendations:
        RecommendationDetailView(recommendation: selectedRecommendation)
    default:
        MessageDetailView(message: selectedMessage)
    }
}
```

### State Management

The 2025 consensus is clear: **use `@Observable` (the Observation framework macro) for all model objects.** It replaces the older `ObservableObject` + `@Published` pattern with better performance (only re-renders views that read changed properties) and less boilerplate.

#### Architecture Layers

```
App (@State for top-level app state)
    |
    +-- AppState (@Observable)
    |       |
    |       +-- selectedView: AppView
    |       +-- selectedAccount: AccountFilter
    |       +-- accounts: [Account]
    |
    +-- EmailStore (@Observable)
    |       |
    |       +-- actionQueue: [Email]
    |       +-- readingQueue: [Email]
    |       +-- filtered: [Email]
    |       +-- allEmails: [Email]
    |       +-- fetch methods, search, etc.
    |
    +-- RecommendationStore (@Observable)
    |       |
    |       +-- recommendations: [Recommendation]
    |       +-- grouped/filtered accessors
    |
    +-- SyncEngine
    |       |
    |       +-- coordinates IMAP fetch across 3 accounts
    |       +-- writes to local persistence
    |       +-- publishes changes to stores
    |
    +-- ClassificationEngine
            |
            +-- processes new emails
            +-- assigns to queues
            +-- extracts recommendations
```

#### Key Patterns

- **@State at the App level** for objects that must survive view rebuilds (AppState, EmailStore, etc.). The App struct is never destroyed, making it the right owner.
- **@Observable on all model/store classes.** No need for @Published.
- **@Bindable** when you need to pass an @Observable object into a child view and create bindings to its properties.
- **Use .task { } instead of .onAppear** for async data loading. It automatically cancels when the view disappears.
- **Keep views thin.** Views read from stores; stores are updated by engines. Views never talk to IMAP directly.

#### Account Filtering

Since emails from all 3 accounts flow into shared queues, filtering is a view-level concern:

```swift
@Observable
class EmailStore {
    var allEmails: [Email] = []

    func emails(for view: AppView, account: AccountFilter) -> [Email] {
        let viewFiltered = allEmails.filter { $0.classification == view.classification }
        switch account {
        case .all: return viewFiltered
        case .work: return viewFiltered.filter { $0.account.isWork }
        case .personal: return viewFiltered.filter { $0.account.isPersonal }
        case .specific(let id): return viewFiltered.filter { $0.account.id == id }
        }
    }
}
```

---

## 3. Keyboard Shortcuts in SwiftUI

This is the trickiest part of the UI. SwiftUI's keyboard support has improved but still has real gaps for "keyboard-first" applications.

### Layer 1: Menu Bar Shortcuts (`.keyboardShortcut()`)

For standard Cmd+key shortcuts, use the `.keyboardShortcut()` modifier on Buttons within `CommandGroup` or `CommandMenu` in the App's `commands` block.

```swift
@main
struct EmailApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .commands {
                CommandMenu("Navigate") {
                    Button("Action Queue") { appState.selectedView = .actionQueue }
                        .keyboardShortcut("1", modifiers: .command)
                    Button("Reading Queue") { appState.selectedView = .readingQueue }
                        .keyboardShortcut("2", modifiers: .command)
                    // ... etc
                }
                CommandMenu("Actions") {
                    Button("Reply") { handleReply() }
                        .keyboardShortcut("r", modifiers: [])
                    Button("Snooze") { handleSnooze() }
                        .keyboardShortcut("s", modifiers: [])
                    Button("Archive") { handleArchive() }
                        .keyboardShortcut("e", modifiers: [])
                }
            }
    }
}
```

This gives you Cmd+1 through Cmd+5 for view switching, plus menu bar visibility for discoverability.

**Limitation:** `.keyboardShortcut()` on Buttons defaults to requiring the Cmd modifier. For plain letter keys (J, K, R, S, E without modifiers), you need to explicitly pass `modifiers: []`. However, this can conflict with text input fields -- when the user is composing a reply, pressing "R" should type the letter, not trigger reply.

### Layer 2: onKeyPress for Vim-Style Navigation

The `onKeyPress` modifier (iOS 17+ / macOS 14+) is the right tool for J/K navigation and other contextual keyboard shortcuts.

```swift
MessageListView()
    .focusable()
    .focused($isListFocused)
    .onKeyPress("j") {
        selectNextMessage()
        return .handled
    }
    .onKeyPress("k") {
        selectPreviousMessage()
        return .handled
    }
    .onKeyPress(.return) {
        openSelectedMessage()
        return .handled
    }
```

**Critical requirement:** The view MUST have `.focusable()` applied AND must actually have focus. Use `@FocusState` to manage which view currently has keyboard focus.

```swift
@FocusState private var focusedArea: FocusArea?

enum FocusArea {
    case sidebar
    case messageList
    case messageDetail
    case composeField
}
```

When `focusedArea == .composeField`, the J/K/R/S shortcuts should NOT fire. Handle this by conditionally applying the onKeyPress modifiers or by returning `.ignored` when in compose mode.

### Layer 3: Focus Management Strategy

The focus system is the key to making keyboard-first work:

```
Tab       -> cycles focus between sidebar, message list, detail
Escape    -> moves focus back to message list from detail
J/K       -> only active when message list is focused
Enter     -> opens message, shifts focus to detail
R         -> opens compose, shifts focus to compose field
Escape    -> (in compose) cancels compose, returns focus to message list
```

Implement a `FocusCoordinator` that manages these transitions:

```swift
@Observable
class FocusCoordinator {
    var activeFocus: FocusArea = .messageList

    func handleTab() {
        activeFocus = switch activeFocus {
        case .sidebar: .messageList
        case .messageList: .messageDetail
        case .messageDetail: .sidebar
        case .composeField: .messageList
        }
    }

    func enterCompose() { activeFocus = .composeField }
    func exitCompose() { activeFocus = .messageList }
}
```

### Layer 4: Platform Differentiation

On macOS, keyboard shortcuts are primary. On iOS, they are secondary (external keyboard users).

```swift
#if os(macOS)
// Full keyboard shortcut suite
MessageListView()
    .onKeyPress("j") { ... }
    .onKeyPress("k") { ... }
#else
// iOS: keyboard shortcuts only for external keyboard via .keyboardShortcut
// Swipe gestures are primary interaction
MessageListView()
    .swipeActions(edge: .trailing) { ... }
#endif
```

### Potential Pitfalls

- **Focus loss:** SwiftUI can lose focus unpredictably during navigation transitions. You may need to explicitly re-set focus after programmatic navigation.
- **Text field conflicts:** When a text field is focused, single-key shortcuts (J, K, etc.) must be suppressed. Use the FocusArea tracking to gate this.
- **List selection vs. onKeyPress:** SwiftUI's `List(selection:)` has its own keyboard handling (arrow keys). This can conflict with custom J/K bindings. You may need to use a custom list implementation rather than the built-in `List` to get full control.
- **No built-in shortcut cheat sheet:** Consider building a custom overlay (triggered by `?` key) that shows all available shortcuts, like many keyboard-first apps do.

---

## 4. Multi-Platform Strategy

### What to Share (100%)

These should live in a Swift Package (e.g., `EmailCore`) with no UI dependencies:

- **Data models:** `Email`, `Account`, `Recommendation`, `Classification`, `SnoozeState`, etc.
- **IMAP/SMTP layer:** The `EmailProvider` protocol and `SwiftMailProvider` implementation
- **Classification engine:** All AI/ML classification logic
- **Recommendation extraction:** Newsletter parsing and recommendation extraction
- **Sync engine:** Whatever sync mechanism is chosen (CloudKit, custom, etc.)
- **Persistence layer:** Database access, queries, migrations (if using GRDB or Core Data, the model/schema layer)
- **Business logic:** Snooze scheduling, digest generation, queue sorting rules, account management

### What to Keep Platform-Specific

- **Navigation structure:** `NavigationSplitView` behaves differently enough between macOS and iOS that each platform benefits from its own root navigation container
- **Keyboard handling:** macOS gets full keyboard shortcut suite; iOS gets swipe gestures
- **Message rendering:** `WKWebView` wrapper will need platform-specific configuration
- **Toolbar and menu bar:** macOS has `CommandMenu`; iOS has toolbar items and context menus
- **Notifications / scheduling:** Different APIs for local notifications and background refresh
- **Compose view:** macOS can use a panel/sheet; iOS uses a full-screen modal

### Recommended Package Structure

```
EmailApp/
    |
    +-- Packages/
    |       |
    |       +-- EmailCore/                    (Swift Package)
    |       |       +-- Sources/
    |       |       |       +-- Models/       (Email, Account, Recommendation, etc.)
    |       |       |       +-- Networking/   (IMAP, SMTP via SwiftMail)
    |       |       |       +-- Storage/      (Database layer)
    |       |       |       +-- Sync/         (Sync engine)
    |       |       |       +-- Classification/ (AI classification)
    |       |       |       +-- Extraction/   (Recommendation extraction)
    |       |       +-- Tests/
    |       |
    |       +-- EmailUI/                      (Swift Package, shared UI components)
    |               +-- Sources/
    |                       +-- Components/   (Reusable views: badges, avatars, timestamps)
    |                       +-- Styles/       (Colors, typography, shared modifiers)
    |
    +-- EmailApp-macOS/                       (macOS app target)
    |       +-- App/
    |       +-- Views/
    |       +-- Navigation/
    |       +-- Keyboard/
    |
    +-- EmailApp-iOS/                         (iOS app target)
    |       +-- App/
    |       +-- Views/
    |       +-- Navigation/
    |
    +-- EmailDaemon/                          (macOS daemon target for background sync)
            +-- main.swift
            +-- SyncService.swift
```

Alternatively, use a single Xcode project with a Multiplatform app target and use `#if os(macOS)` / `#if os(iOS)` for platform-specific views. This is simpler to start with but can get messy as the platform-specific code grows. The separate targets approach scales better.

### Shared UI Components

Some UI is genuinely shareable:

- **Email row view:** The basic cell showing sender, subject, snippet, timestamp, account color dot
- **Badge views:** Unread count, snooze count ("snoozed 3x"), classification labels
- **Recommendation card:** Title, source, context snippet, status indicator
- **Digest view:** The daily digest content layout

Keep these in the `EmailUI` package. Use `ViewModifier` and environment values to let each platform customize appearance without forking the component.

---

## 5. Email Rendering

HTML email rendering is one of the hardest parts of building an email client. Emails contain arbitrary HTML, often malformed, with inline CSS, images, tracking pixels, and occasionally malicious content.

### Approach: WKWebView (Current Best Practice)

Wrap `WKWebView` in a SwiftUI representable for both platforms. This gives you the full WebKit rendering engine with security sandboxing.

```swift
// macOS
struct EmailWebView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        // ... security configuration
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(sanitizedHTML(htmlContent), baseURL: nil)
    }
}

// iOS
struct EmailWebView: UIViewRepresentable {
    // Same pattern with UIView instead of NSView
}
```

### Future: Native SwiftUI WebView (iOS 26+)

WWDC 2025 introduced a native `WebView` component in SwiftUI for iOS 26. This eliminates the UIViewRepresentable/NSViewRepresentable bridging. However, it requires iOS 26 as the minimum deployment target, which is too new to rely on today. Plan to migrate to it once iOS 26 adoption is sufficient (likely 2026-2027).

### Security Configuration (Critical)

Email HTML is untrusted content. The WKWebView must be locked down:

```swift
func configureForEmail(_ config: WKWebViewConfiguration) {
    // 1. Disable JavaScript entirely
    config.defaultWebpagePreferences.allowsContentJavaScript = false

    // 2. Use non-persistent data store (no cookies, no cache leaking between emails)
    config.websiteDataStore = .nonPersistent()

    // 3. Block all navigation away from the loaded content
    //    (implemented via WKNavigationDelegate)

    // 4. Set Content Security Policy via user script
    let csp = """
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'unsafe-inline'; img-src data: cid:;">
    """
    let script = WKUserScript(
        source: "document.head.insertAdjacentHTML('afterbegin', '\(csp)');",
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
    config.userContentController.addUserScript(script)
}
```

### Image Loading Strategy

Remote images in emails are the primary tracking mechanism (tracking pixels). Handle with a three-tier approach:

1. **Default: Block all remote images.** Only show inline/embedded images (CID references, base64 data URIs).
2. **Per-sender allowlist.** If the user trusts a sender, allow remote images for that sender.
3. **Proxy option (future).** Route remote image requests through a proxy that strips tracking parameters.

Implement via `WKNavigationDelegate`:

```swift
func webView(_ webView: WKWebView,
             decidePolicyFor navigationAction: WKNavigationAction,
             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = navigationAction.request.url else {
        decisionHandler(.cancel)
        return
    }

    // Allow data: and cid: URLs (inline content)
    if url.scheme == "data" || url.scheme == "cid" {
        decisionHandler(.allow)
        return
    }

    // Block everything else (remote loads, navigation)
    decisionHandler(.cancel)

    // If it was a link click, open in system browser
    if navigationAction.navigationType == .linkActivated {
        NSWorkspace.shared.open(url)  // macOS
        // UIApplication.shared.open(url)  // iOS
    }
}
```

### HTML Sanitization

Before loading into WKWebView, sanitize the HTML:

- Strip `<script>` tags (defense in depth, even though JS is disabled)
- Strip `<form>` tags (prevent phishing forms)
- Rewrite external stylesheet `<link>` tags to inline or remove
- Strip event handler attributes (`onclick`, `onload`, etc.)
- Optionally inject a custom stylesheet for consistent typography

Consider using a library like **SwiftSoup** for HTML parsing and sanitization.

### Alternative: AttributedString for Plain Text Emails

For plain text emails (or as a lightweight fallback), render using SwiftUI's `Text` with `AttributedString`. This avoids the overhead of WKWebView for simple messages:

```swift
if email.isPlainText {
    ScrollView {
        Text(email.attributedBody)
            .textSelection(.enabled)
            .font(.body)
            .padding()
    }
} else {
    EmailWebView(htmlContent: email.htmlBody)
}
```

---

## 6. Local Data Storage

An email client has specific data patterns that constrain the storage choice:

- **High record counts:** Thousands to tens of thousands of emails across 3 accounts
- **Full-text search is essential:** "Find that email about the budget from last month"
- **Frequent writes:** New emails arriving, classification updates, snooze state changes
- **Complex queries:** Filter by account + classification + date range + search term
- **Relationships:** Emails to accounts, emails to recommendations, threads

### Option A: SwiftData

Apple's newest persistence framework, built as a modern Swift replacement for Core Data.

**Pros:**
- Native SwiftUI integration via @Query macro
- Clean declarative model definitions using @Model macro
- Automatic CloudKit sync support (could help with device sync)
- Less boilerplate than Core Data

**Cons:**
- Performance is measurably slower than Core Data for large datasets (as of 2025)
- No NSFetchedResultsController equivalent -- lacks the lazy-loading optimization that makes Core Data efficient with large lists
- No built-in full-text search (FTS) support
- Missing NSCompoundPredicate -- complex multi-condition predicates are harder
- Missing GROUP BY operations
- Younger framework with more bugs and fewer escape hatches
- Not suitable for the daemon process (daemon is not a SwiftUI app, so @Query is irrelevant)

**Verdict:** Too immature for an email client's data patterns. The lack of FTS and the performance gap are dealbreakers.

### Option B: Core Data

The established Apple persistence framework. Mature, powerful, but verbose.

**Pros:**
- 15+ years of optimization; handles large datasets well
- NSFetchedResultsController provides efficient lazy loading with batch fetching
- fetchBatchSize keeps memory usage low when scrolling large lists
- Works with SwiftUI via @FetchRequest (built on NSFetchedResultsController)
- Can be configured with Spotlight integration for system-wide search
- Mature migration system for schema changes
- Works in both app and daemon processes

**Cons:**
- No built-in full-text search (the underlying SQLite FTS is not exposed)
- Verbose setup: model editor, managed object context, persistent container
- Thread safety requires careful context management
- The Objective-C heritage shows through in the API

**Verdict:** Solid choice if you supplement it with a separate FTS index. The maturity and SwiftUI integration are strong points.

### Option C: GRDB.swift (SQLite directly)

A Swift toolkit for SQLite that provides a clean API over raw SQLite, including first-class FTS5 support.

**Pros:**
- Direct access to SQLite's full power, including FTS5 full-text search
- FTS5 support is a first-class feature: create FTS tables, custom tokenizers, relevance ranking
- External content tables let you index email bodies without duplicating storage
- Excellent performance -- you are writing SQL, so you control query plans
- Active maintenance (v7.9.0 released December 2025)
- Works perfectly in both app and daemon processes
- Point-Free's SharingGRDB (v0.6.0) adds full-text search integration with their sharing framework
- No Objective-C baggage; pure Swift
- Record types can conform to Codable

**Cons:**
- No built-in SwiftUI integration (@FetchRequest equivalent) -- you write your own observation layer
- You own the schema, migrations, and query layer entirely
- No automatic CloudKit sync (you build your own sync)
- More code to write upfront compared to Core Data

**Verdict:** The best fit for an email client. FTS5 is a killer feature for email search, and direct SQLite control means you can optimize the exact queries you need.

### Option D: Realm

Cross-platform mobile database.

**Pros:**
- Built-in sync via MongoDB Atlas (if you want cloud sync)
- Object-oriented API
- Good performance for reads

**Cons:**
- MongoDB acquisition has made the future uncertain
- Threading model is different from Swift concurrency (can cause friction)
- Not a natural fit for the Apple ecosystem
- No FTS support comparable to SQLite FTS5

**Verdict:** Not recommended. The ecosystem uncertainty and lack of FTS make it a poor choice.

### Recommendation: GRDB.swift

**GRDB is the strongest choice for this project.** The reasoning:

1. **FTS5 is essential.** Email search is a core feature. GRDB gives first-class access to SQLite's FTS5 with custom tokenizers, relevance ranking, and external content tables. No other option provides this without significant workarounds.

2. **Daemon compatibility.** The Mac Mini daemon that pulls and classifies email needs database access. GRDB works identically in a daemon process, a SwiftUI app, or a CLI tool. Core Data and SwiftData are more opinionated about their runtime context.

3. **Performance control.** With thousands of emails and complex filtering (account + classification + date + search), you want to write optimized SQL rather than hoping an ORM generates the right query.

4. **Migration control.** Email schemas evolve (new classification types, recommendation fields, etc.). GRDB gives explicit migration control.

### Schema Sketch

```sql
-- Core email storage
CREATE TABLE email (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    message_id TEXT,          -- IMAP Message-ID header
    uid INTEGER,              -- IMAP UID
    folder TEXT,
    from_address TEXT,
    from_name TEXT,
    to_addresses TEXT,        -- JSON array
    cc_addresses TEXT,        -- JSON array
    subject TEXT,
    snippet TEXT,             -- First ~200 chars of body
    html_body TEXT,
    text_body TEXT,
    date_received INTEGER,    -- Unix timestamp
    date_processed INTEGER,
    classification TEXT,      -- action, reading, filtered, transactional
    is_read INTEGER DEFAULT 0,
    is_archived INTEGER DEFAULT 0,
    snooze_count INTEGER DEFAULT 0,
    snooze_until INTEGER,     -- Unix timestamp, NULL if not snoozed
    has_attachments INTEGER DEFAULT 0,
    raw_headers TEXT,         -- Full headers for re-classification
    FOREIGN KEY (account_id) REFERENCES account(id)
);

-- Full-text search index (external content, avoids duplicating text)
CREATE VIRTUAL TABLE email_fts USING fts5(
    subject, text_body, from_name, from_address,
    content='email',
    content_rowid='rowid'
);

-- Recommendations extracted from newsletters
CREATE TABLE recommendation (
    id TEXT PRIMARY KEY,
    email_id TEXT,
    type TEXT,                -- book, movie, music, article, podcast, other
    title TEXT,
    creator TEXT,             -- author, artist, director, etc.
    source_name TEXT,         -- "Stratechery", "Dense Discovery", etc.
    source_date INTEGER,
    context_snippet TEXT,
    status TEXT DEFAULT 'new', -- new, saved, done, dismissed
    confidence REAL,
    FOREIGN KEY (email_id) REFERENCES email(id)
);

-- Accounts
CREATE TABLE account (
    id TEXT PRIMARY KEY,
    name TEXT,
    email_address TEXT,
    imap_host TEXT,
    imap_port INTEGER,
    smtp_host TEXT,
    smtp_port INTEGER,
    type TEXT,                -- work, personal
    color TEXT                -- hex color for visual distinction
);

-- Snooze history (for tracking "snoozed 3x" and patterns)
CREATE TABLE snooze_event (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email_id TEXT,
    snoozed_at INTEGER,
    snooze_until INTEGER,
    FOREIGN KEY (email_id) REFERENCES email(id)
);
```

### SwiftUI Observation Layer

Since GRDB does not have built-in SwiftUI observation, build a thin layer using `@Observable` and GRDB's `ValueObservation`:

```swift
@Observable
class EmailStore {
    private let db: DatabaseQueue
    var actionQueueEmails: [Email] = []

    init(db: DatabaseQueue) {
        self.db = db
        startObserving()
    }

    private func startObserving() {
        let observation = ValueObservation.tracking { db in
            try Email
                .filter(Column("classification") == "action")
                .order(Column("snooze_until").desc, Column("date_received").desc)
                .fetchAll(db)
        }
        // observation.start(in:) publishes changes that update the array
    }
}
```

---

## 7. Background Processing on macOS

The Mac Mini runs 24/7 as the AI processing hub. It needs a background process that:
- Continuously pulls email from 3 IMAP accounts
- Runs classification on new emails
- Extracts recommendations from newsletters
- Generates daily digests at 6 AM and 7 PM
- Writes results to the shared database / sync layer

### Architecture Options

#### Option A: Launch Agent with XPC (Recommended)

A Launch Agent is a per-user background process managed by launchd. It runs in the user's session and has access to the user's keychain (for IMAP credentials) and file system.

**Structure:**
- **EmailDaemon:** A standalone Swift executable, registered as a Launch Agent
- **EmailApp:** The main SwiftUI app, communicates with the daemon via XPC

```
EmailApp.app
    |
    +-- Contents/
            +-- Library/
                    +-- LoginItems/
                            +-- EmailDaemon  (the background agent)
```

**Registration via SMAppService:**

```swift
import ServiceManagement

// In the main app, register the daemon as a login item
let service = SMAppService.agent(plistName: "com.yourname.emaildaemon.plist")
try service.register()
```

The agent's launchd plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.emaildaemon</string>
    <key>Program</key>
    <string>/path/to/EmailDaemon</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

`RunAtLoad` starts it at login. `KeepAlive` restarts it if it crashes. This is exactly what you want for continuous email polling.

**XPC Communication:**

The daemon and the app communicate via XPC (inter-process communication). The daemon exposes a service:

```swift
// In EmailDaemon
let listener = NSXPCListener(machServiceName: "com.yourname.emaildaemon")
listener.delegate = self
listener.resume()

// XPC Interface
@objc protocol EmailDaemonProtocol {
    func fetchNow(completion: @escaping (Bool) -> Void)
    func getStatus(completion: @escaping (DaemonStatus) -> Void)
    func reclassify(emailId: String, newClassification: String,
                    completion: @escaping (Bool) -> Void)
}
```

The main app connects:

```swift
let connection = NSXPCConnection(machServiceName: "com.yourname.emaildaemon")
connection.remoteObjectInterface = NSXPCInterface(with: EmailDaemonProtocol.self)
connection.resume()

let daemon = connection.remoteObjectProxy as? EmailDaemonProtocol
daemon?.fetchNow { success in
    // ...
}
```

**Pros:**
- Apple's sanctioned way to run background services on macOS
- launchd handles lifecycle (start at login, restart on crash, stop at logout)
- XPC provides secure, efficient IPC between daemon and app
- User approval is shown in System Settings > Login Items (builds trust)
- Access to user keychain for credentials

**Cons:**
- Requires learning XPC, which has an Objective-C-flavored API
- Daemon is a separate build target to maintain
- Sandboxing and entitlements can be tricky (the daemon needs its own entitlements)
- Debugging two processes simultaneously is more complex

#### Option B: Main App with Background Modes

Keep everything in the main app, which runs in the background when not in the foreground.

**Pros:**
- Simpler architecture -- single process
- No XPC complexity
- Shared memory space

**Cons:**
- The app must be running (even if in the background) -- if the user quits the app, email stops syncing
- macOS can suspend background apps, especially under memory pressure
- No guarantee of continuous execution
- The "always on" requirement from the brief is not reliably met

**Verdict:** Not reliable enough for a 24/7 email processing hub.

#### Option C: Full Launch Daemon (Root-Level)

A system-level daemon running as root.

**Pros:**
- Runs regardless of user login
- Maximum reliability

**Cons:**
- Requires root privileges -- user must authenticate to install
- Cannot access user keychain directly
- Overkill for a personal email client
- More complex security model

**Verdict:** Overkill. A Launch Agent is sufficient since the Mac Mini has a logged-in user session.

### Recommendation: Launch Agent + XPC

The Launch Agent approach is the right one. It gives:
- Reliable 24/7 operation (as long as the user is logged in, which is always on the Mac Mini)
- Clean separation between the UI app and the background processing
- Standard macOS lifecycle management via launchd
- Secure IPC via XPC

### Daemon Internal Architecture

```swift
// EmailDaemon main.swift
@main
struct EmailDaemon {
    static func main() async throws {
        let db = try DatabaseQueue(path: sharedDatabasePath)
        let accounts = try loadAccounts(from: db)

        // Start IMAP IDLE connections for real-time push
        let imapMonitors = accounts.map { account in
            IMAPMonitor(account: account, db: db)
        }
        for monitor in imapMonitors {
            await monitor.startMonitoring()
        }

        // Schedule periodic full sync (backup for IDLE)
        let syncScheduler = SyncScheduler(accounts: accounts, db: db)
        await syncScheduler.schedulePeriodicSync(interval: .minutes(5))

        // Schedule digest generation
        let digestGenerator = DigestGenerator(db: db)
        await digestGenerator.scheduleMorningDigest(at: "06:00")
        await digestGenerator.scheduleEveningDigest(at: "19:00")

        // Start XPC listener for app communication
        let xpcService = XPCService(db: db, monitors: imapMonitors)
        xpcService.startListening()

        // Keep the daemon alive
        RunLoop.main.run()
    }
}
```

### IMAP IDLE for Real-Time Push

Rather than polling every N minutes, use IMAP IDLE to get push notifications of new emails. Each account maintains a persistent IDLE connection:

```swift
actor IMAPMonitor {
    let account: Account
    let db: DatabaseQueue

    func startMonitoring() async {
        while true {
            do {
                let server = try await IMAPServer(
                    host: account.imapHost,
                    port: account.imapPort
                )
                try await server.login(username: account.username,
                                       password: account.password)
                try await server.select(mailbox: "INBOX")

                // Enter IDLE mode -- blocks until new mail arrives
                for try await event in server.idle() {
                    switch event {
                    case .newMessage(let uid):
                        let email = try await server.fetch(uid: uid)
                        try await processNewEmail(email)
                    case .connectionLost:
                        break  // Will reconnect in outer loop
                    }
                }
            } catch {
                // Log error, wait, reconnect
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}
```

Note: IDLE support depends on the IMAP library. SwiftMail may not have IDLE out of the box yet -- this may require extending it or dropping down to the swift-nio-imap layer for the IDLE command.

### Shared Database Between Daemon and App

Both the daemon and the main app access the same SQLite database. GRDB handles this well with WAL (Write-Ahead Logging) mode, which allows concurrent reads and writes from multiple processes:

```swift
// Shared database path (in Application Support or a shared app group container)
let sharedDatabasePath = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("EmailApp/emails.db")
    .path

// Both daemon and app open with WAL mode
var config = Configuration()
config.prepareDatabase { db in
    // WAL mode enables concurrent access from multiple processes
    try db.execute(sql: "PRAGMA journal_mode=WAL")
}
let db = try DatabaseQueue(path: sharedDatabasePath, configuration: config)
```

The app observes database changes via GRDB's `ValueObservation` and updates the UI in real time as the daemon writes new emails.

---

## Summary of Recommendations

| Area | Recommendation | Rationale |
|---|---|---|
| IMAP Library | SwiftMail (with EmailProvider abstraction) | Modern async/await, actor-based, built on Apple's SwiftNIO IMAP |
| App Architecture | NavigationSplitView + @Observable stores | Apple's standard multi-column nav; modern state management |
| State Management | @Observable macro, @State at App level | Best performance, least boilerplate, 2025 consensus |
| Keyboard Shortcuts | .keyboardShortcut for Cmd+key, onKeyPress for J/K | Layered approach; focus management is critical |
| Multi-Platform | EmailCore Swift Package (shared) + per-platform UI targets | Clean separation; testable core logic |
| Email Rendering | WKWebView with JS disabled, remote images blocked | Security first; migrate to native WebView when iOS 26 is baseline |
| Local Storage | GRDB.swift with FTS5 | Full-text search, daemon-compatible, performance control |
| Background Processing | Launch Agent via SMAppService + XPC | Reliable 24/7 operation, clean IPC with main app |

### Critical Path Items

1. **Prototype the IMAP layer first.** Connect to all 3 accounts using SwiftMail, fetch messages, verify it handles the email types you receive. This will surface any gaps early.

2. **Set up the GRDB schema and FTS5 index.** Get email storage and search working before building UI. The database is the foundation everything else rests on.

3. **Build the daemon skeleton.** Get the Launch Agent registered, XPC communication working, and basic IMAP polling running. This is the most architecturally novel piece and benefits from early validation.

4. **Build the macOS UI first.** It is the primary platform (keyboard-first, always-on use). The iOS version can follow once the data layer and macOS UI are solid.

---

## Key Risks and Mitigations

| Risk | Mitigation |
|---|---|
| SwiftMail is too young and hits a blocker | EmailProvider protocol abstraction allows swapping to MailCore2 or raw SwiftNIO IMAP |
| IMAP IDLE not supported by SwiftMail | Implement polling as fallback; extend SwiftMail or use swift-nio-imap directly for IDLE |
| WKWebView email rendering edge cases (malformed HTML) | HTML sanitization layer; plain text fallback; test with real emails from all 3 accounts early |
| Focus management breaks under complex navigation | Invest in a FocusCoordinator early; consider NSHostingView escape hatch for the message list if SwiftUI focus is unreliable |
| GRDB observation layer is more work than Core Data @FetchRequest | Budget time upfront; the FTS5 payoff is worth it |
| XPC between daemon and app is fiddly | Start with a minimal protocol; expand incrementally; plenty of Apple sample code and community examples exist |
