# Thin SwiftUI Client Architecture

Brainstorm document for the macOS and iOS email client apps. These are thin API consumers -- the Go backend on the Mac Mini handles all IMAP fetching, AI classification, recommendation extraction, digest generation, and SMTP sending. The Swift clients render UI, accept user input, and communicate with the server over REST and WebSocket APIs.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Shared Swift Package (EmailClientKit)](#2-shared-swift-package-emailclientkit)
3. [macOS App Architecture](#3-macos-app-architecture)
4. [Keyboard System (macOS)](#4-keyboard-system-macos)
5. [iOS App Architecture](#5-ios-app-architecture)
6. [Email Rendering](#6-email-rendering)
7. [Newsletter Reading View](#7-newsletter-reading-view)
8. [Recommendations View](#8-recommendations-view)
9. [Compose and Reply](#9-compose-and-reply)
10. [Snooze UX](#10-snooze-ux)
11. [Real-Time Updates](#11-real-time-updates)
12. [Offline Behavior](#12-offline-behavior)
13. [Account Switching and Filtering](#13-account-switching-and-filtering)

---

## 1. Project Structure

### Architectural Principle

The Swift clients are deliberately thin. They do not:
- Connect to IMAP servers
- Run classification models
- Parse MIME structures
- Extract recommendations from newsletters
- Generate digests

They do:
- Call the Go server's REST API to fetch data
- Maintain a WebSocket connection for real-time updates
- Render email HTML securely
- Accept user input (compose, snooze, archive, classify override)
- Send user actions to the server via REST
- Cache data locally for offline viewing

### Recommended Directory Layout

```
EmailApp/
|
+-- Packages/
|       |
|       +-- EmailClientKit/                   (Swift Package -- shared code)
|               +-- Package.swift
|               +-- Sources/
|               |       +-- Models/           (API response/request structs)
|               |       +-- Networking/       (REST client, WebSocket manager)
|               |       +-- Cache/            (Local caching layer)
|               |       +-- Utilities/        (Date formatting, color mapping, etc.)
|               +-- Tests/
|                       +-- ModelsTests/
|                       +-- NetworkingTests/
|
+-- macOS/                                    (macOS app target)
|       +-- EmailApp_macOS.swift              (App entry point)
|       +-- Stores/                           (Observable stores)
|       |       +-- EmailStore.swift
|       |       +-- RecommendationStore.swift
|       |       +-- DigestStore.swift
|       |       +-- ComposeStore.swift
|       +-- Views/
|       |       +-- Sidebar/
|       |       |       +-- SidebarView.swift
|       |       |       +-- SidebarRow.swift
|       |       +-- EmailList/
|       |       |       +-- EmailListView.swift
|       |       |       +-- EmailRowView.swift
|       |       |       +-- SnoozeReturnBanner.swift
|       |       +-- Detail/
|       |       |       +-- EmailDetailView.swift
|       |       |       +-- EmailWebView.swift
|       |       +-- Reading/
|       |       |       +-- NewsletterReaderView.swift
|       |       +-- Recommendations/
|       |       |       +-- RecommendationListView.swift
|       |       |       +-- RecommendationCard.swift
|       |       |       +-- RecommendationDetailView.swift
|       |       +-- Digest/
|       |       |       +-- DigestView.swift
|       |       |       +-- DigestSection.swift
|       |       +-- Compose/
|       |       |       +-- ComposeView.swift
|       |       |       +-- AccountPicker.swift
|       |       +-- Snooze/
|       |       |       +-- SnoozePickerView.swift
|       |       +-- CommandPalette/
|       |       |       +-- CommandPaletteView.swift
|       |       |       +-- CommandItem.swift
|       |       +-- Shared/
|       |               +-- AccountDot.swift
|       |               +-- BadgeView.swift
|       |               +-- OfflineBanner.swift
|       +-- Keyboard/
|       |       +-- KeyboardManager.swift
|       |       +-- FocusCoordinator.swift
|       +-- Commands/
|       |       +-- AppCommands.swift          (Menu bar commands)
|       +-- Resources/
|               +-- Assets.xcassets
|
+-- iOS/                                      (iOS app target)
|       +-- EmailApp_iOS.swift                (App entry point)
|       +-- Stores/                           (Same Observable stores, or shared via package)
|       +-- Views/
|       |       +-- Tabs/
|       |       |       +-- MainTabView.swift
|       |       +-- EmailList/
|       |       |       +-- EmailListView_iOS.swift
|       |       |       +-- EmailRowView_iOS.swift
|       |       +-- Detail/
|       |       |       +-- EmailDetailView_iOS.swift
|       |       +-- Reading/
|       |       |       +-- NewsletterReaderView_iOS.swift
|       |       +-- Recommendations/
|       |       |       +-- RecommendationListView_iOS.swift
|       |       +-- Digest/
|       |       |       +-- DigestView_iOS.swift
|       |       +-- Compose/
|       |       |       +-- ComposeView_iOS.swift
|       |       +-- Snooze/
|       |       |       +-- SnoozePickerView_iOS.swift
|       |       +-- Shared/
|       |               +-- AccountDot.swift   (can share with macOS via package)
|       +-- Resources/
|               +-- Assets.xcassets
|
+-- EmailApp.xcodeproj                        (or .xcworkspace)
```

### Xcode Project Configuration

Use a single Xcode project with two app targets (macOS and iOS) and one local Swift Package (`EmailClientKit`). Both app targets depend on the shared package.

**Why two separate app targets rather than a multiplatform target:**
- NavigationSplitView behaves differently enough on macOS vs iOS that the root navigation container should be platform-specific.
- macOS has extensive keyboard handling, menu bar commands, and window management that do not apply to iOS.
- iOS has TabView, swipe actions, and pull-to-refresh that do not apply to macOS.
- The shared package handles all code that can genuinely be shared (models, networking, caching). The platform-specific targets handle UI.

**Alternative considered:** A single multiplatform target using `#if os(macOS)` / `#if os(iOS)` throughout. This works for small apps but becomes messy as the platform-specific code grows. Given the extensive macOS keyboard system and the different iOS navigation paradigm, separate targets scale better.

### Shared vs Platform-Specific Breakdown

**In EmailClientKit (shared):**
- All API model structs (Email, Classification, Recommendation, Digest, SnoozeState, Account)
- REST API client (all endpoint calls)
- WebSocket connection manager
- Local cache layer
- Date/time formatting utilities
- Account color mapping
- Notification scheduling logic

**In macOS target:**
- NavigationSplitView-based layout
- Full keyboard shortcut system
- Command palette
- Menu bar integration
- Window management (main window, compose window)
- NSViewRepresentable for WKWebView

**In iOS target:**
- TabView + NavigationStack layout
- Swipe gesture actions
- Pull-to-refresh
- UIViewRepresentable for WKWebView
- iPad NavigationSplitView adaptation

**Potentially shared UI components (could go in EmailClientKit or a separate EmailUI package):**
- AccountDot (colored circle for account identification)
- BadgeView (unread count, snooze count)
- Timestamp formatting views
- Recommendation card layout (if similar enough across platforms)

---

## 2. Shared Swift Package (EmailClientKit)

### Package.swift

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EmailClientKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "EmailClientKit", targets: ["EmailClientKit"])
    ],
    targets: [
        .target(name: "EmailClientKit"),
        .testTarget(name: "EmailClientKitTests", dependencies: ["EmailClientKit"])
    ]
)
```

Minimum deployment targets: macOS 15 (Sequoia) and iOS 18. These provide `@Observable`, `onKeyPress`, and the latest SwiftUI navigation APIs. No external dependencies -- URLSession handles all networking.

### Model Layer

All models are plain Swift structs conforming to `Codable`, `Identifiable`, and `Sendable`. They mirror the Go server's JSON response shapes exactly.

```swift
// MARK: - Account

struct Account: Codable, Identifiable, Sendable {
    let id: String
    let name: String              // "Work", "Personal", "Personal 2"
    let emailAddress: String
    let type: AccountType         // .work, .personal
    let color: String             // Hex color string: "#3B82F6"

    enum AccountType: String, Codable, Sendable {
        case work
        case personal
    }
}

// MARK: - Email

struct Email: Codable, Identifiable, Sendable {
    let id: String                // Server-assigned stable ID
    let accountID: String
    let messageID: String         // RFC 2822 Message-ID
    let threadID: String?         // For conversation grouping
    let from: Contact
    let to: [Contact]
    let cc: [Contact]
    let subject: String
    let snippet: String           // First ~200 chars, server-generated
    let receivedAt: Date
    let classification: Classification
    let isRead: Bool
    let isArchived: Bool
    let hasAttachments: Bool
    let snoozeState: SnoozeState?
    let labels: [String]

    struct Contact: Codable, Sendable {
        let name: String?
        let email: String
    }

    enum Classification: String, Codable, Sendable {
        case actionRequired
        case newsletter
        case filtered
        case transactional
    }
}

// MARK: - Email Detail (fetched on demand, includes full body)

struct EmailDetail: Codable, Identifiable, Sendable {
    let id: String
    let email: Email              // All metadata
    let htmlBody: String?         // Sanitized HTML from server
    let textBody: String?         // Plain text fallback
    let attachments: [Attachment]

    struct Attachment: Codable, Identifiable, Sendable {
        let id: String
        let filename: String
        let mimeType: String
        let size: Int             // Bytes
    }
}

// MARK: - Snooze

struct SnoozeState: Codable, Sendable {
    let snoozedAt: Date
    let returnAt: Date
    let snoozeCount: Int          // How many times snoozed
    let isActive: Bool
}

// MARK: - Recommendation

struct Recommendation: Codable, Identifiable, Sendable {
    let id: String
    let type: RecommendationType
    let title: String
    let creator: String?          // Author, director, artist
    let sourceNewsletterName: String
    let sourceDate: Date
    let contextSnippet: String    // The paragraph mentioning it
    let status: RecommendationStatus
    let duplicateCount: Int       // "Recommended by N sources"
    let duplicateSources: [DuplicateSource]?

    enum RecommendationType: String, Codable, Sendable {
        case book, movie, tv, music, article, podcast, other
    }

    enum RecommendationStatus: String, Codable, Sendable {
        case new, saved, done, dismissed
    }

    struct DuplicateSource: Codable, Sendable {
        let newsletterName: String
        let date: Date
        let contextSnippet: String
    }
}

// MARK: - Daily Digest

struct DailyDigest: Codable, Identifiable, Sendable {
    let id: String
    let generatedAt: Date
    let digestType: DigestType
    let actionQueueCount: Int
    let snoozedReturningToday: [SnoozedItem]
    let readingQueueCount: Int
    let borderlineItems: [BorderlineItem]
    let notableTransactional: [TransactionalHighlight]
    let sentCount: Int?           // Evening only
    let archivedCount: Int?       // Evening only
    let multiSnoozeNudges: [SnoozeNudge]

    enum DigestType: String, Codable, Sendable {
        case morning, evening
    }

    struct SnoozedItem: Codable, Sendable {
        let emailID: String
        let subject: String
        let returnAt: Date
    }

    struct BorderlineItem: Codable, Sendable {
        let emailID: String
        let subject: String
        let from: String
        let explanation: String   // AI-generated reason it might matter
    }

    struct TransactionalHighlight: Codable, Sendable {
        let emailID: String
        let highlightType: String // "package_arriving", "large_charge"
        let displayText: String
    }

    struct SnoozeNudge: Codable, Sendable {
        let emailID: String
        let subject: String
        let snoozeCount: Int
        let daysSinceFirstSnooze: Int
    }
}
```

### Date Handling

The Go server sends dates as ISO 8601 strings (RFC 3339). Configure a shared decoder:

```swift
extension JSONDecoder {
    static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
```

Use `convertFromSnakeCase` / `convertToSnakeCase` so Go-style `snake_case` JSON keys map to Swift-style `camelCase` properties automatically. If the Go server uses camelCase in its JSON responses instead, remove the key coding strategies.

### API Client

A single `APIClient` actor handles all REST communication. It is an actor to serialize requests and manage the auth token safely across concurrent calls.

```swift
actor APIClient {
    private let session: URLSession
    private var baseURL: URL
    private let decoder = JSONDecoder.apiDecoder
    private let encoder = JSONEncoder.apiEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Server Discovery

    /// Update the base URL (e.g., when switching from Tailscale to local)
    func updateBaseURL(_ url: URL) {
        self.baseURL = url
    }

    // MARK: - Email Endpoints

    func fetchEmails(
        view: AppView,
        account: AccountFilter = .all,
        page: Int = 1,
        pageSize: Int = 50
    ) async throws -> PaginatedResponse<Email> {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/emails"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "view", value: view.rawValue),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if case .specific(let id) = account {
            components.queryItems?.append(URLQueryItem(name: "account_id", value: id))
        } else if case .accountType(let type) = account {
            components.queryItems?.append(URLQueryItem(name: "account_type", value: type.rawValue))
        }
        return try await get(components.url!)
    }

    func fetchEmailDetail(id: String) async throws -> EmailDetail {
        return try await get(baseURL.appendingPathComponent("/api/emails/\(id)"))
    }

    func archiveEmail(id: String) async throws {
        try await post(baseURL.appendingPathComponent("/api/emails/\(id)/archive"), body: EmptyBody())
    }

    func snoozeEmail(id: String, until: Date) async throws {
        let body = SnoozeRequest(returnAt: until)
        try await post(baseURL.appendingPathComponent("/api/emails/\(id)/snooze"), body: body)
    }

    func reclassifyEmail(id: String, newClassification: Email.Classification) async throws {
        let body = ReclassifyRequest(classification: newClassification)
        try await post(baseURL.appendingPathComponent("/api/emails/\(id)/reclassify"), body: body)
    }

    func markRead(id: String) async throws {
        try await post(baseURL.appendingPathComponent("/api/emails/\(id)/read"), body: EmptyBody())
    }

    // MARK: - Recommendation Endpoints

    func fetchRecommendations(
        type: Recommendation.RecommendationType? = nil,
        status: Recommendation.RecommendationStatus? = nil
    ) async throws -> [Recommendation] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/recommendations"), resolvingAgainstBaseURL: false)!
        components.queryItems = []
        if let type { components.queryItems?.append(URLQueryItem(name: "type", value: type.rawValue)) }
        if let status { components.queryItems?.append(URLQueryItem(name: "status", value: status.rawValue)) }
        return try await get(components.url!)
    }

    func updateRecommendationStatus(id: String, status: Recommendation.RecommendationStatus) async throws {
        let body = RecommendationStatusUpdate(status: status)
        try await post(baseURL.appendingPathComponent("/api/recommendations/\(id)/status"), body: body)
    }

    // MARK: - Digest Endpoints

    func fetchLatestDigest() async throws -> DailyDigest {
        return try await get(baseURL.appendingPathComponent("/api/digest/latest"))
    }

    func fetchDigest(id: String) async throws -> DailyDigest {
        return try await get(baseURL.appendingPathComponent("/api/digest/\(id)"))
    }

    // MARK: - Compose Endpoints

    func sendEmail(_ draft: ComposeDraft) async throws {
        try await post(baseURL.appendingPathComponent("/api/send"), body: draft)
    }

    func saveDraft(_ draft: ComposeDraft) async throws -> ComposeDraft {
        return try await post(baseURL.appendingPathComponent("/api/drafts"), body: draft)
    }

    // MARK: - Account Endpoints

    func fetchAccounts() async throws -> [Account] {
        return try await get(baseURL.appendingPathComponent("/api/accounts"))
    }

    // MARK: - Search

    func search(query: String, account: AccountFilter = .all) async throws -> [Email] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return try await get(components.url!)
    }

    // MARK: - Internal HTTP Methods

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(_ url: URL, body: B) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func post<B: Encodable>(_ url: URL, body: B) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Supporting Types

struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}

enum AccountFilter: Sendable {
    case all
    case accountType(Account.AccountType)
    case specific(String)
}

enum AppView: String, CaseIterable, Sendable {
    case actionQueue = "action_queue"
    case readingQueue = "reading_queue"
    case recommendations = "recommendations"
    case filtered = "filtered"
    case allInboxes = "all_inboxes"
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case serverUnreachable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "Server error (HTTP \(code))"
        case .decodingError(let err): return "Failed to parse response: \(err.localizedDescription)"
        case .serverUnreachable: return "Cannot reach server"
        }
    }
}

struct EmptyBody: Codable {}
struct SnoozeRequest: Codable { let returnAt: Date }
struct ReclassifyRequest: Codable { let classification: Email.Classification }
struct RecommendationStatusUpdate: Codable { let status: Recommendation.RecommendationStatus }
```

### WebSocket Manager

The WebSocket connection receives real-time pushes from the server: new emails, classification changes, snooze returns, and recommendation updates. The client does not need to poll.

```swift
actor WebSocketManager {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var baseURL: URL
    private var isConnected = false
    private var reconnectAttempt = 0
    private let maxReconnectDelay: TimeInterval = 60

    // Continuation-based event stream for consumers
    private var eventContinuation: AsyncStream<ServerEvent>.Continuation?
    let events: AsyncStream<ServerEvent>

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)

        var continuation: AsyncStream<ServerEvent>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.eventContinuation = continuation
    }

    func connect() async {
        guard !isConnected else { return }

        let wsURL = baseURL
            .appendingPathComponent("/ws")
        // Convert http(s) to ws(s)
        var components = URLComponents(url: wsURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"

        let task = session.webSocketTask(with: components.url!)
        task.resume()
        self.webSocketTask = task
        self.isConnected = true
        self.reconnectAttempt = 0

        await receiveLoop()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while isConnected {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8),
                       let event = try? JSONDecoder.apiDecoder.decode(ServerEvent.self, from: data) {
                        eventContinuation?.yield(event)
                    }
                case .data(let data):
                    if let event = try? JSONDecoder.apiDecoder.decode(ServerEvent.self, from: data) {
                        eventContinuation?.yield(event)
                    }
                @unknown default:
                    break
                }
            } catch {
                // Connection lost
                isConnected = false
                eventContinuation?.yield(.connectionLost)
                await reconnect()
                break
            }
        }
    }

    private func reconnect() async {
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt)), maxReconnectDelay)
        try? await Task.sleep(for: .seconds(delay))
        await connect()
    }

    /// Send a ping to keep the connection alive
    func sendPing() async {
        try? await webSocketTask?.sendPing(pongReceiveHandler: { _ in })
    }
}

// MARK: - Server Events

enum ServerEvent: Codable, Sendable {
    case newEmail(Email)
    case emailUpdated(Email)                   // Classification change, read state, etc.
    case emailArchived(String)                 // Email ID
    case snoozeReturn(Email)                   // Snoozed email returning to queue
    case newRecommendation(Recommendation)
    case recommendationUpdated(Recommendation)
    case digestAvailable(DailyDigest)
    case connectionLost                        // Client-side, not from server

    // Custom Codable with a "type" discriminator field
    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "new_email":
            self = .newEmail(try container.decode(Email.self, forKey: .payload))
        case "email_updated":
            self = .emailUpdated(try container.decode(Email.self, forKey: .payload))
        case "email_archived":
            self = .emailArchived(try container.decode(String.self, forKey: .payload))
        case "snooze_return":
            self = .snoozeReturn(try container.decode(Email.self, forKey: .payload))
        case "new_recommendation":
            self = .newRecommendation(try container.decode(Recommendation.self, forKey: .payload))
        case "recommendation_updated":
            self = .recommendationUpdated(try container.decode(Recommendation.self, forKey: .payload))
        case "digest_available":
            self = .digestAvailable(try container.decode(DailyDigest.self, forKey: .payload))
        default:
            // Unknown event type -- ignore gracefully for forward compatibility
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        // Client rarely needs to encode events, but included for completeness
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .newEmail(let email):
            try container.encode("new_email", forKey: .type)
            try container.encode(email, forKey: .payload)
        // ... other cases
        case .connectionLost:
            try container.encode("connection_lost", forKey: .type)
        default:
            break
        }
    }
}
```

### Server Discovery

The client needs to find the Go server. It might be on the local network (home) or reachable via Tailscale (away from home).

```swift
actor ServerDiscovery {
    enum ConnectionMethod: Sendable {
        case local(URL)       // e.g., http://mac-mini.local:8080
        case tailscale(URL)   // e.g., http://100.x.x.x:8080
        case configured(URL)  // User-specified URL in settings
    }

    private var preferredMethod: ConnectionMethod?

    /// Try to discover the server, preferring local network, falling back to Tailscale
    func discover() async -> ConnectionMethod? {
        // 1. If user has configured a URL, use it
        if let configured = UserDefaults.standard.string(forKey: "serverURL"),
           let url = URL(string: configured) {
            if await isReachable(url) {
                return .configured(url)
            }
        }

        // 2. Try local network (Bonjour / mDNS or hardcoded local address)
        if let localURL = URL(string: "http://mac-mini.local:8080"),
           await isReachable(localURL) {
            return .local(localURL)
        }

        // 3. Try Tailscale IP
        if let tailscaleIP = UserDefaults.standard.string(forKey: "tailscaleIP"),
           let tailscaleURL = URL(string: "http://\(tailscaleIP):8080"),
           await isReachable(tailscaleURL) {
            return .tailscale(tailscaleURL)
        }

        return nil
    }

    private func isReachable(_ url: URL) async -> Bool {
        let healthURL = url.appendingPathComponent("/health")
        do {
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
```

**Server discovery flow on app launch:**
1. Check for a user-configured URL in settings. If set and reachable, use it.
2. Try the local network address (Bonjour or a configured hostname like `mac-mini.local`).
3. Try the Tailscale IP (stored in settings after initial setup).
4. If nothing is reachable, show the offline banner and retry periodically.

The server URL should be settable in the app's settings view. The Tailscale IP might change; consider implementing Bonjour/mDNS service advertisement on the Go server so the client can discover it automatically on the local network without hardcoding an address.

### Error Handling and Retry Logic

```swift
enum RetryPolicy {
    case noRetry
    case exponentialBackoff(maxAttempts: Int, baseDelay: TimeInterval)

    static let standard = RetryPolicy.exponentialBackoff(maxAttempts: 3, baseDelay: 1.0)
}

extension APIClient {
    func withRetry<T>(
        policy: RetryPolicy = .standard,
        operation: () async throws -> T
    ) async throws -> T {
        switch policy {
        case .noRetry:
            return try await operation()
        case .exponentialBackoff(let maxAttempts, let baseDelay):
            var lastError: Error?
            for attempt in 0..<maxAttempts {
                do {
                    return try await operation()
                } catch {
                    lastError = error
                    if attempt < maxAttempts - 1 {
                        let delay = baseDelay * pow(2.0, Double(attempt))
                        try? await Task.sleep(for: .seconds(delay))
                    }
                }
            }
            throw lastError ?? APIError.serverUnreachable
        }
    }
}
```

Use retry logic for idempotent GET requests. For POST requests (archive, snooze, send), do not retry automatically to avoid duplicate actions. Instead, report the error to the user and let them retry manually.

---

## 3. macOS App Architecture

### Navigation Structure

The macOS app uses a three-column NavigationSplitView: sidebar (view selector) -> email list -> detail/reader.

```swift
@main
struct EmailApp_macOS: App {
    @State private var appState = AppState()
    @State private var emailStore = EmailStore()
    @State private var recommendationStore = RecommendationStore()
    @State private var digestStore = DigestStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(emailStore)
                .environment(recommendationStore)
                .environment(digestStore)
        }
        .commands {
            AppCommands(appState: appState, emailStore: emailStore)
        }

        // Separate compose window
        Window("Compose", id: "compose") {
            ComposeView()
                .environment(appState)
        }
        .defaultSize(width: 600, height: 500)
        .keyboardShortcut("n", modifiers: .command)
    }
}
```

```swift
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showCommandPalette = false

    var body: some View {
        @Bindable var state = appState

        NavigationSplitView {
            SidebarView(selection: $state.selectedView)
        } content: {
            switch appState.selectedView {
            case .actionQueue, .readingQueue, .filtered, .allInboxes:
                EmailListView(view: appState.selectedView)
            case .recommendations:
                RecommendationListView()
            }
        } detail: {
            DetailColumn()
        }
        .navigationSplitViewStyle(.balanced)
        .overlay {
            if showCommandPalette {
                CommandPaletteView(isPresented: $showCommandPalette)
            }
        }
        .onKeyPress(.init("k"), modifiers: .command) {
            showCommandPalette.toggle()
            return .handled
        }
    }
}
```

### @Observable Stores

Stores are the intermediary between the API client and the views. Each store holds the relevant data, triggers fetches, and processes WebSocket events.

```swift
@Observable
class AppState {
    var selectedView: AppView = .actionQueue
    var selectedEmailID: String?
    var accountFilter: AccountFilter = .all
    var accounts: [Account] = []
    var isOnline = true
    var showComposeWindow = false

    // Connection state
    var connectionMethod: ServerDiscovery.ConnectionMethod?
}

@Observable
class EmailStore {
    // Data per view
    var actionQueue: [Email] = []
    var readingQueue: [Email] = []
    var filtered: [Email] = []
    var allInboxes: [Email] = []

    // Loading states
    var isLoading = false
    var error: APIError?

    // The selected email's full detail
    var selectedDetail: EmailDetail?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadEmails(for view: AppView, account: AccountFilter = .all) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await apiClient.fetchEmails(view: view, account: account)
            switch view {
            case .actionQueue: actionQueue = response.items
            case .readingQueue: readingQueue = response.items
            case .filtered: filtered = response.items
            case .allInboxes: allInboxes = response.items
            case .recommendations: break // Handled by RecommendationStore
            }
            error = nil
        } catch let err as APIError {
            error = err
        } catch {
            self.error = .serverUnreachable
        }
    }

    func loadDetail(for emailID: String) async {
        do {
            selectedDetail = try await apiClient.fetchEmailDetail(id: emailID)
        } catch {
            // Handle error
        }
    }

    func archive(_ emailID: String) async {
        do {
            try await apiClient.archiveEmail(id: emailID)
            // Remove from local arrays optimistically
            removeEmail(id: emailID)
        } catch {
            // Revert optimistic update, show error
        }
    }

    func snooze(_ emailID: String, until: Date) async {
        do {
            try await apiClient.snoozeEmail(id: emailID, until: until)
            removeEmail(id: emailID)
        } catch {
            // Handle error
        }
    }

    // MARK: - WebSocket Event Handling

    func handleEvent(_ event: ServerEvent) {
        switch event {
        case .newEmail(let email):
            insertEmail(email)
        case .emailUpdated(let email):
            updateEmail(email)
        case .emailArchived(let id):
            removeEmail(id: id)
        case .snoozeReturn(let email):
            // Insert at top of action queue with visual distinction
            actionQueue.insert(email, at: 0)
        default:
            break
        }
    }

    private func insertEmail(_ email: Email) {
        switch email.classification {
        case .actionRequired:
            actionQueue.insert(email, at: appropriateIndex(for: email, in: actionQueue))
        case .newsletter:
            readingQueue.insert(email, at: 0)
        case .filtered:
            filtered.insert(email, at: 0)
        case .transactional:
            break // Only visible in allInboxes
        }
        allInboxes.insert(email, at: 0)
    }

    private func updateEmail(_ email: Email) {
        // Replace the email in all arrays where it might exist
        for i in actionQueue.indices where actionQueue[i].id == email.id {
            actionQueue[i] = email
        }
        // ... repeat for other arrays
    }

    private func removeEmail(id: String) {
        actionQueue.removeAll { $0.id == id }
        readingQueue.removeAll { $0.id == id }
        filtered.removeAll { $0.id == id }
        // Do not remove from allInboxes (archived emails are still visible there)
    }

    private func appropriateIndex(for email: Email, in list: [Email]) -> Int {
        // Snoozed returns go to top. Otherwise, sort by receivedAt descending.
        if email.snoozeState?.isActive == false && email.snoozeState != nil {
            // This is a snooze return -- insert at the very top
            return 0
        }
        // Find insertion point to maintain reverse-chronological order
        return list.firstIndex { $0.receivedAt < email.receivedAt } ?? list.endIndex
    }
}

@Observable
class RecommendationStore {
    var recommendations: [Recommendation] = []
    var selectedTypeFilter: Recommendation.RecommendationType?
    var selectedStatusFilter: Recommendation.RecommendationStatus?
    var isLoading = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    var filteredRecommendations: [Recommendation] {
        recommendations.filter { rec in
            if let type = selectedTypeFilter, rec.type != type { return false }
            if let status = selectedStatusFilter, rec.status != status { return false }
            return true
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recommendations = try await apiClient.fetchRecommendations()
        } catch {
            // Handle error
        }
    }

    func updateStatus(_ id: String, to status: Recommendation.RecommendationStatus) async {
        // Optimistic update
        if let index = recommendations.firstIndex(where: { $0.id == id }) {
            // Note: Recommendation is a struct, so we would need a mutable copy mechanism
            // or update the entire array. This is a simplification.
        }
        do {
            try await apiClient.updateRecommendationStatus(id: id, status: status)
        } catch {
            // Revert
        }
    }

    func handleEvent(_ event: ServerEvent) {
        switch event {
        case .newRecommendation(let rec):
            recommendations.insert(rec, at: 0)
        case .recommendationUpdated(let rec):
            if let index = recommendations.firstIndex(where: { $0.id == rec.id }) {
                recommendations[index] = rec
            }
        default:
            break
        }
    }
}

@Observable
class DigestStore {
    var latestDigest: DailyDigest?
    var isLoading = false

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadLatest() async {
        isLoading = true
        defer { isLoading = false }
        do {
            latestDigest = try await apiClient.fetchLatestDigest()
        } catch {
            // Handle error
        }
    }

    func handleEvent(_ event: ServerEvent) {
        if case .digestAvailable(let digest) = event {
            latestDigest = digest
        }
    }
}
```

### View-to-Store Binding and WebSocket Event Routing

A central coordinator connects the WebSocket event stream to the appropriate stores:

```swift
@Observable
class AppCoordinator {
    let apiClient: APIClient
    let webSocket: WebSocketManager
    let emailStore: EmailStore
    let recommendationStore: RecommendationStore
    let digestStore: DigestStore

    private var eventTask: Task<Void, Never>?

    init(serverURL: URL) {
        self.apiClient = APIClient(baseURL: serverURL)
        self.webSocket = WebSocketManager(baseURL: serverURL)
        self.emailStore = EmailStore(apiClient: apiClient)
        self.recommendationStore = RecommendationStore(apiClient: apiClient)
        self.digestStore = DigestStore(apiClient: apiClient)
    }

    func start() async {
        await webSocket.connect()
        startEventRouting()
    }

    func stop() async {
        eventTask?.cancel()
        await webSocket.disconnect()
    }

    private func startEventRouting() {
        eventTask = Task {
            for await event in await webSocket.events {
                await MainActor.run {
                    emailStore.handleEvent(event)
                    recommendationStore.handleEvent(event)
                    digestStore.handleEvent(event)
                }
            }
        }
    }
}
```

The coordinator is created at app launch and injected into the environment. Views read from the stores. User actions go through the stores, which call the API client.

### Window Management

**Main window:** The NavigationSplitView with sidebar, list, and detail.

**Compose window:** A separate window opened with Cmd+N. Use SwiftUI's `Window` scene with an `id` so only one compose window is open at a time. For reply, pass the reply context (original email ID, reply-to address, quoted text) through the environment or a shared compose store.

```swift
// Opening compose from a reply action
@Environment(\.openWindow) private var openWindow

func handleReply() {
    composeStore.prepareReply(to: selectedEmail)
    openWindow(id: "compose")
}
```

### Menu Bar Integration

The app should show a subtle menu bar icon that displays:
- Number of items in the Action Queue
- Connection status (online/offline indicator)
- Quick access to compose

Use `MenuBarExtra` for this:

```swift
MenuBarExtra {
    Text("Action Queue: \(emailStore.actionQueue.count)")
    Divider()
    Button("New Email") { openWindow(id: "compose") }
        .keyboardShortcut("n", modifiers: .command)
    Divider()
    Text(appState.isOnline ? "Connected" : "Offline")
} label: {
    Image(systemName: "envelope.badge")
}
.menuBarExtraStyle(.menu)
```

---

## 4. Keyboard System (macOS)

### Layer 1: Menu Bar Shortcuts via .keyboardShortcut()

These are global shortcuts that work regardless of which view has focus, registered through the `commands` modifier on the Scene.

```swift
struct AppCommands: Commands {
    let appState: AppState
    let emailStore: EmailStore

    var body: some Commands {
        // View switching
        CommandMenu("Navigate") {
            Button("Action Queue") { appState.selectedView = .actionQueue }
                .keyboardShortcut("1", modifiers: .command)
            Button("Reading Queue") { appState.selectedView = .readingQueue }
                .keyboardShortcut("2", modifiers: .command)
            Button("Recommendations") { appState.selectedView = .recommendations }
                .keyboardShortcut("3", modifiers: .command)
            Button("Filtered") { appState.selectedView = .filtered }
                .keyboardShortcut("4", modifiers: .command)
            Button("All Inboxes") { appState.selectedView = .allInboxes }
                .keyboardShortcut("5", modifiers: .command)
            Button("Daily Digest") { /* show digest */ }
                .keyboardShortcut("d", modifiers: .command)
        }

        // Account filtering
        CommandMenu("Accounts") {
            Button("All Accounts") { appState.accountFilter = .all }
                .keyboardShortcut("1", modifiers: [.command, .shift])
            Button("Work Only") { appState.accountFilter = .accountType(.work) }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            Button("Personal Only") { appState.accountFilter = .accountType(.personal) }
                .keyboardShortcut("3", modifiers: [.command, .shift])
        }
    }
}
```

These appear in the menu bar, giving discoverability. Users can see "Navigate > Action Queue Cmd+1" in the menu.

### Layer 2: Vim-Style Navigation via onKeyPress

J/K navigation and single-key action shortcuts are contextual -- they only fire when the email list has focus, and they must not fire when a text field (compose, search) is focused.

```swift
struct EmailListView: View {
    @Environment(EmailStore.self) private var store
    @FocusState private var isFocused: Bool
    @State private var selectedIndex: Int = 0

    var body: some View {
        let emails = currentEmails

        List(selection: bindingForSelectedID) {
            ForEach(emails) { email in
                EmailRowView(email: email)
            }
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress("j") {
            guard isFocused else { return .ignored }
            selectNext()
            return .handled
        }
        .onKeyPress("k") {
            guard isFocused else { return .ignored }
            selectPrevious()
            return .handled
        }
        .onKeyPress(.return) {
            guard isFocused else { return .ignored }
            openSelected()
            return .handled
        }
        .onKeyPress("e") {
            guard isFocused else { return .ignored }
            archiveSelected()
            return .handled
        }
        .onKeyPress("s") {
            guard isFocused else { return .ignored }
            showSnoozePicker()
            return .handled
        }
        .onKeyPress("r") {
            guard isFocused else { return .ignored }
            replyToSelected()
            return .handled
        }
        .onKeyPress("/") {
            guard isFocused else { return .ignored }
            focusSearchField()
            return .handled
        }
    }

    private func selectNext() {
        let emails = currentEmails
        if selectedIndex < emails.count - 1 {
            selectedIndex += 1
            store.selectedDetail = nil // Clear detail, will load on selection change
        }
    }

    private func selectPrevious() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }
}
```

### Layer 3: Command Palette (Cmd+K)

A floating overlay with fuzzy search across all available actions. This is the bridge between discoverability and speed -- new users search for actions, power users memorize the direct shortcut.

```swift
struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    let commands: [PaletteCommand] = PaletteCommand.allCommands

    var filteredCommands: [PaletteCommand] {
        if searchText.isEmpty { return commands }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.keywords.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .font(.title3)
            }
            .padding()

            Divider()

            // Results list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                        CommandRow(
                            command: command,
                            isSelected: index == selectedIndex
                        )
                        .onTapGesture {
                            execute(command)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            if let command = filteredCommands[safe: selectedIndex] {
                execute(command)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private func execute(_ command: PaletteCommand) {
        command.action()
        isPresented = false
    }
}

struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let shortcut: String?         // Display string like "Cmd+1"
    let icon: String              // SF Symbol name
    let keywords: [String]        // Extra search terms
    let action: () -> Void

    static var allCommands: [PaletteCommand] {
        [
            PaletteCommand(
                title: "Action Queue",
                shortcut: "Cmd+1",
                icon: "exclamationmark.circle",
                keywords: ["inbox", "todo", "respond"],
                action: { /* navigate */ }
            ),
            PaletteCommand(
                title: "Snooze Email",
                shortcut: "S",
                icon: "clock",
                keywords: ["defer", "later", "remind"],
                action: { /* snooze */ }
            ),
            // ... all other commands
        ]
    }
}

struct CommandRow: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: command.icon)
                .frame(width: 24)
            Text(command.title)
            Spacer()
            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
```

The key UX detail borrowed from Superhuman: showing the direct keyboard shortcut on the right side of each command row. This teaches users the shortcut as they search, so they gradually memorize the shortcuts for their most-used actions and stop needing the palette.

### Layer 4: Focus Management

Focus coordination is critical for keyboard-first UX. Without it, keypresses go to the wrong view or get lost entirely.

```swift
enum FocusArea: Hashable {
    case sidebar
    case emailList
    case emailDetail
    case composeBody
    case searchField
    case commandPalette
    case snoozePicker
}

@Observable
class FocusCoordinator {
    var activeFocus: FocusArea = .emailList

    var isTextInputFocused: Bool {
        switch activeFocus {
        case .composeBody, .searchField, .commandPalette:
            return true
        default:
            return false
        }
    }

    func handleTab() {
        activeFocus = switch activeFocus {
        case .sidebar: .emailList
        case .emailList: .emailDetail
        case .emailDetail: .sidebar
        default: .emailList
        }
    }

    func handleEscape() {
        switch activeFocus {
        case .emailDetail: activeFocus = .emailList
        case .composeBody: activeFocus = .emailList
        case .searchField: activeFocus = .emailList
        case .commandPalette: activeFocus = .emailList
        case .snoozePicker: activeFocus = .emailList
        default: break
        }
    }

    func enterCompose() { activeFocus = .composeBody }
    func enterSearch() { activeFocus = .searchField }
    func enterSnoozePicker() { activeFocus = .snoozePicker }
}
```

**Critical rules:**
- When `isTextInputFocused` is true, single-key shortcuts (J, K, R, S, E) must not fire. Only modifier-based shortcuts (Cmd+1, Cmd+K) work during text input.
- When opening the email detail view (Enter), focus shifts to the detail pane.
- When pressing Escape in the detail view, focus returns to the email list.
- When composing a reply (R), focus shifts to the compose text field.
- Tab cycles through sidebar -> list -> detail.
- The command palette captures all keyboard input when open; Escape dismisses it.

### Handling Conflicts Between onKeyPress and Text Fields

The fundamental problem: when a TextField or TextEditor has focus, pressing "J" should type the letter "j", not navigate the email list.

**Solution:** Gate all single-key onKeyPress handlers on the focus state:

```swift
.onKeyPress("j") {
    guard !focusCoordinator.isTextInputFocused else { return .ignored }
    selectNext()
    return .handled
}
```

Returning `.ignored` when a text field is focused lets the keypress fall through to the text field for normal text input.

**Alternative approach if onKeyPress gating is unreliable:** Use the `Commands` system for all shortcuts, including single-key ones. Register single-key shortcuts with `modifiers: []` but conditionally disable them (by disabling the Button) when a text field has focus. This is less elegant but more robust since the Commands system has well-defined priority over text input.

### Full Shortcut Reference

| Shortcut | Action | Layer | Notes |
|----------|--------|-------|-------|
| Cmd+1 | Action Queue | Commands | Global, always works |
| Cmd+2 | Reading Queue | Commands | Global |
| Cmd+3 | Recommendations | Commands | Global |
| Cmd+4 | Filtered | Commands | Global |
| Cmd+5 | All Inboxes | Commands | Global |
| Cmd+D | Daily Digest | Commands | Global |
| Cmd+Shift+1 | Work accounts only | Commands | Global |
| Cmd+Shift+2 | Personal accounts only | Commands | Global |
| Cmd+Shift+3 | All accounts | Commands | Global |
| Cmd+K | Command palette | onKeyPress | Global overlay |
| Cmd+N | New compose | Window | Opens compose window |
| J | Navigate down | onKeyPress | List focus only |
| K | Navigate up | onKeyPress | List focus only |
| Enter | Open email | onKeyPress | List focus only |
| Escape | Go back | onKeyPress | Returns to list from detail |
| R | Reply | onKeyPress | List/detail focus only |
| S | Snooze | onKeyPress | List/detail, opens picker |
| E | Archive | onKeyPress | List/detail focus only |
| / | Search | onKeyPress | Focuses search field |
| ? | Shortcut help | onKeyPress | Shows shortcut overlay |
| Tab | Cycle focus areas | onKeyPress | Sidebar -> list -> detail |
| Cmd+Enter | Send email | Commands | Compose window only |

---

## 5. iOS App Architecture

### Navigation Structure

iOS uses a TabView as the primary navigation container, with a NavigationStack inside each tab.

```swift
@main
struct EmailApp_iOS: App {
    @State private var appState = AppState()
    @State private var emailStore = EmailStore()
    @State private var recommendationStore = RecommendationStore()
    @State private var digestStore = DigestStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .environment(emailStore)
                .environment(recommendationStore)
                .environment(digestStore)
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            Tab("Action", systemImage: "exclamationmark.circle") {
                NavigationStack {
                    EmailListView_iOS(view: .actionQueue)
                }
            }
            .badge(appState.actionQueueCount)

            Tab("Reading", systemImage: "book") {
                NavigationStack {
                    EmailListView_iOS(view: .readingQueue)
                }
            }
            // No badge -- Reading Queue should not create urgency

            Tab("Recs", systemImage: "star") {
                NavigationStack {
                    RecommendationListView_iOS()
                }
            }

            Tab("Filtered", systemImage: "tray") {
                NavigationStack {
                    EmailListView_iOS(view: .filtered)
                }
            }

            Tab("All", systemImage: "envelope") {
                NavigationStack {
                    EmailListView_iOS(view: .allInboxes)
                }
            }
        }
    }
}
```

**Badge philosophy:** Only the Action Queue tab shows a badge (unread count). The Reading Queue, Filtered, and All Inboxes tabs do not show badges. Badges create low-grade anxiety; only the "needs response" queue warrants that attention signal.

### NavigationStack Within Each Tab

Each tab contains a NavigationStack for push navigation:

```swift
struct EmailListView_iOS: View {
    let view: AppView
    @Environment(EmailStore.self) private var store
    @State private var selectedEmailID: String?

    var body: some View {
        List(currentEmails) { email in
            NavigationLink(value: email.id) {
                EmailRowView_iOS(email: email)
            }
            .swipeActions(edge: .trailing) {
                Button("Archive", systemImage: "archivebox") {
                    Task { await store.archive(email.id) }
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button("Snooze", systemImage: "clock") {
                    showSnoozePicker(for: email.id)
                }
                .tint(.orange)
            }
            .swipeActions(edge: .leading) {
                Button("Reclassify", systemImage: "arrow.triangle.branch") {
                    showReclassifyMenu(for: email.id)
                }
                .tint(.purple)
            }
        }
        .navigationTitle(view.displayName)
        .navigationDestination(for: String.self) { emailID in
            if view == .readingQueue {
                NewsletterReaderView_iOS(emailID: emailID)
            } else {
                EmailDetailView_iOS(emailID: emailID)
            }
        }
        .refreshable {
            await store.loadEmails(for: view)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountFilterMenu()
            }
        }
    }
}
```

### Swipe Gestures

Swipe gestures are the primary interaction mechanism on iOS (replacing keyboard shortcuts):

- **Swipe right-to-left (trailing):** Archive (primary), Snooze (secondary)
- **Swipe left-to-right (leading):** Reclassify (move to different queue)

The swipe actions mirror the macOS keyboard shortcuts: E (archive), S (snooze), and reclassification.

### Pull-to-Refresh

Every email list view supports pull-to-refresh using `.refreshable`. This triggers a fresh fetch from the server. In practice, the WebSocket connection should keep the list current, so pull-to-refresh is a fallback / reassurance mechanism.

### iPad Adaptation

On iPad, the TabView can be replaced or supplemented with a NavigationSplitView for a more desktop-like experience:

```swift
struct MainView_iPad: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                SidebarView_iOS(selection: $appState.selectedView)
            } content: {
                EmailListView_iOS(view: appState.selectedView)
            } detail: {
                DetailView_iOS()
            }
        } else {
            MainTabView()
        }
    }
}
```

Alternatively, use SwiftUI's automatic adaptation: NavigationSplitView on iPad automatically collapses to a stack-based navigation on iPhone. However, the tab bar is a better fit for iPhone because it provides persistent access to all five views without navigating back to a sidebar.

### Daily Digest on iOS

The Daily Digest is accessible from a toolbar button in any tab, presented as a sheet:

```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button(action: { showDigest = true }) {
            Image(systemName: "newspaper")
        }
    }
}
.sheet(isPresented: $showDigest) {
    DigestView_iOS()
}
```

---

## 6. Email Rendering

### WKWebView Wrapper

HTML email rendering uses WKWebView wrapped for SwiftUI. The wrapper is platform-specific (NSViewRepresentable on macOS, UIViewRepresentable on iOS) but the configuration is shared.

```swift
// Shared configuration (in EmailClientKit or a shared file)
func configureWebViewForEmail(_ config: WKWebViewConfiguration) {
    // 1. Disable JavaScript entirely
    config.defaultWebpagePreferences.allowsContentJavaScript = false

    // 2. Non-persistent data store (no cookies, no cache leaking between emails)
    config.websiteDataStore = .nonPersistent()

    // 3. Content Security Policy -- block all external resources by default
    let cspMeta = """
    <meta http-equiv="Content-Security-Policy" \
    content="default-src 'none'; style-src 'unsafe-inline'; img-src data: cid:;">
    """
    let cspScript = WKUserScript(
        source: "document.head.insertAdjacentHTML('afterbegin', `\(cspMeta)`);",
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
    config.userContentController.addUserScript(cspScript)

    // 4. Inject dark mode support stylesheet
    let darkModeCSS = """
    @media (prefers-color-scheme: dark) {
        body {
            background-color: #1a1a1a !important;
            color: #e0e0e0 !important;
        }
        a { color: #6cb4ee !important; }
        img { opacity: 0.9; }
    }
    """
    let darkModeScript = WKUserScript(
        source: """
        var style = document.createElement('style');
        style.textContent = `\(darkModeCSS)`;
        document.head.appendChild(style);
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )
    config.userContentController.addUserScript(darkModeScript)
}
```

### macOS WKWebView Wrapper

```swift
struct EmailWebView: NSViewRepresentable {
    let htmlContent: String
    let onLinkClicked: (URL) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        configureWebViewForEmail(config)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let wrappedHTML = wrapInHTMLDocument(htmlContent)
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkClicked: onLinkClicked)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onLinkClicked: (URL) -> Void

        init(onLinkClicked: @escaping (URL) -> Void) {
            self.onLinkClicked = onLinkClicked
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Allow initial HTML load and inline content
            if url.scheme == "about" || url.scheme == "data" || url.scheme == "cid" {
                decisionHandler(.allow)
                return
            }

            // Block everything else; open links in system browser
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated {
                onLinkClicked(url)
                NSWorkspace.shared.open(url)
            }
        }
    }
}
```

### iOS WKWebView Wrapper

The iOS version is identical in structure but uses UIViewRepresentable and UIApplication for link opening. This is a case where a protocol-based approach could share more code, but the representable boilerplate is small enough that duplication is acceptable.

### Security Summary

| Concern | Mitigation |
|---------|------------|
| JavaScript execution | Disabled via `allowsContentJavaScript = false` |
| External image loading (tracking) | Blocked by CSP; only `data:` and `cid:` allowed |
| Cookie/session leaking | Non-persistent data store per email render |
| Navigation away from email | Blocked by navigation delegate; links open in system browser |
| Form submission (phishing) | Forms stripped by server-side sanitization + JS disabled |
| External CSS loading | Blocked by CSP `default-src 'none'` |
| Iframes | Blocked by CSP |

### HTML Sanitization

The Go server should sanitize HTML before sending it to the client. The client's WKWebView security configuration is defense-in-depth. Server-side sanitization strips:
- `<script>` tags
- `<form>` tags
- `<iframe>` tags
- Event handler attributes (`onclick`, `onload`, `onerror`, etc.)
- External `<link>` stylesheet references
- `<object>`, `<embed>`, `<applet>` tags

The server injects a base stylesheet for consistent typography and dark mode support.

### Plain Text Fallback

For plain text emails (no HTML body), render with native SwiftUI:

```swift
if let htmlBody = emailDetail.htmlBody {
    EmailWebView(htmlContent: htmlBody) { url in
        // Handle link click
    }
} else if let textBody = emailDetail.textBody {
    ScrollView {
        Text(textBody)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .padding()
    }
}
```

### Dark Mode

Dark mode for email rendering is tricky because email HTML often has hardcoded white backgrounds and dark text. The approach:

1. Inject a CSS `@media (prefers-color-scheme: dark)` block that inverts the default background and text colors.
2. Apply `!important` to override inline styles where possible.
3. Reduce image opacity slightly in dark mode so bright images do not blind the user.
4. Accept that some emails will look imperfect in dark mode. This is a universal problem -- even Apple Mail and Gmail have imperfect dark mode email rendering.

---

## 7. Newsletter Reading View

### Design Philosophy

The Reading Queue is not an inbox -- it is a read-later app embedded in the email client. The UX should feel like Instapaper or Pocket: calm, focused, comfortable for extended reading.

### Reader View Layout

```swift
struct NewsletterReaderView: View {
    let emailDetail: EmailDetail
    @State private var scrollProgress: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(emailDetail.email.subject)
                        .font(.system(.title, design: .serif))
                        .fontWeight(.bold)

                    HStack {
                        AccountDot(accountID: emailDetail.email.accountID)
                        Text(emailDetail.email.from.name ?? emailDetail.email.from.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(emailDetail.email.receivedAt, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, readerPadding)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Divider()
                    .padding(.horizontal, readerPadding)

                // Content
                if let htmlBody = emailDetail.htmlBody {
                    NewsletterWebView(htmlContent: htmlBody)
                        .frame(maxWidth: maxReadingWidth)
                } else if let textBody = emailDetail.textBody {
                    Text(textBody)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(6)
                        .padding(.horizontal, readerPadding)
                }
            }
            .frame(maxWidth: .infinity)
            .background(GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollProgressKey.self,
                    value: calculateProgress(geo)
                )
            })
        }
        .onPreferenceChange(ScrollProgressKey.self) { scrollProgress = $0 }
        .safeAreaInset(edge: .top) {
            // Thin progress bar at top
            ProgressView(value: scrollProgress)
                .tint(.accentColor)
                .scaleEffect(x: 1, y: 0.5)
        }
    }

    private var readerPadding: CGFloat { 40 }
    private var maxReadingWidth: CGFloat { 700 }
}
```

### Typography Specifications

For comfortable reading, the newsletter renderer should apply:

| Property | Value | Rationale |
|----------|-------|-----------|
| Font family | Serif (system serif or custom) | Easier on the eyes for long-form reading |
| Body font size | 18-20px | Larger than default for comfortable reading |
| Line height | 1.6-1.7 | Generous spacing reduces eye strain |
| Max content width | 700px | Optimal line length for readability (50-75 characters per line) |
| Horizontal padding | 40px minimum | Breathing room at the edges |
| Paragraph spacing | 1.2em | Clear visual separation between paragraphs |
| Link color | Muted blue (#6CB4EE in dark mode) | Visible but not distracting |

These should be injected as a CSS stylesheet into the WKWebView used for newsletter rendering. The newsletter WKWebView gets a different configuration from the standard email WKWebView -- the reading view applies the reader stylesheet while the standard email view preserves the original formatting.

### Progress Indicator

A thin progress bar at the top of the reading view shows how far the user has scrolled through the newsletter. This helps with partially-read newsletters -- the user can see at a glance whether they finished or abandoned partway through.

Track the scroll position using a GeometryReader preference key and report it as a 0.0-1.0 value.

The progress could optionally be persisted to the server (via a `PATCH /api/emails/{id}/read-progress` endpoint) so that the reading position syncs across devices. This is a nice-to-have, not essential for v1.

### Swipe Gestures in Reading View

On both platforms, the reader view should support:
- **Swipe left (or left-edge swipe on iOS):** Navigate back to the list
- In the email list, swipe actions provide: Archive, Mark Partially Read

On macOS, the J/K keys should navigate between newsletters in the reading queue without returning to the list -- press K to go to the previous newsletter, J to go to the next.

---

## 8. Recommendations View

### Card-Based Layout

```swift
struct RecommendationListView: View {
    @Environment(RecommendationStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            RecommendationFilterBar()

            // Card grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.filteredRecommendations) { rec in
                        RecommendationCard(recommendation: rec)
                    }
                }
                .padding()
            }
        }
    }

    private var columns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]
        #else
        [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 16)]
        #endif
    }
}
```

### Filter Bar

A horizontal filter strip at the top of the recommendations view:

```swift
struct RecommendationFilterBar: View {
    @Environment(RecommendationStore.self) private var store

    let types: [(Recommendation.RecommendationType?, String, String)] = [
        (nil, "All", "square.grid.2x2"),
        (.book, "Books", "book"),
        (.movie, "Movies", "film"),
        (.tv, "TV", "tv"),
        (.music, "Music", "music.note"),
        (.article, "Articles", "doc.text"),
        (.podcast, "Podcasts", "mic"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.1) { type, label, icon in
                    FilterChip(
                        label: label,
                        icon: icon,
                        isSelected: store.selectedTypeFilter == type
                    ) {
                        store.selectedTypeFilter = (store.selectedTypeFilter == type) ? nil : type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}
```

### Recommendation Card

```swift
struct RecommendationCard: View {
    let recommendation: Recommendation
    @Environment(RecommendationStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type badge and status
            HStack {
                TypeBadge(type: recommendation.type)
                Spacer()
                StatusIndicator(status: recommendation.status)
            }

            // Title and creator
            Text(recommendation.title)
                .font(.headline)
                .lineLimit(2)
            if let creator = recommendation.creator {
                Text(creator)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Context snippet
            Text(recommendation.contextSnippet)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            // Source and duplicate count
            HStack {
                Text("From \(recommendation.sourceNewsletterName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if recommendation.duplicateCount > 1 {
                    Text("Recommended by \(recommendation.duplicateCount) sources")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fontWeight(.medium)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                StatusButton(label: "Save", icon: "bookmark", status: .saved)
                StatusButton(label: "Done", icon: "checkmark", status: .done)
                StatusButton(label: "Dismiss", icon: "xmark", status: .dismissed)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
```

### Status Management

Recommendation statuses: New, Saved, Done, Dismissed.

- **New:** Default state after extraction. Displayed with no special badge.
- **Saved:** User intends to engage with this recommendation. Equivalent to Goodreads "Want to Read" or Letterboxd "Watchlist."
- **Done:** User has read/watched/listened. Moved to a "Done" filter for reference.
- **Dismissed:** User is not interested. Removed from default view but still searchable.

Status changes are a single tap on the card or a keyboard shortcut when the recommendation is selected. The action sends a POST to the server, which records it and pushes the update to all connected clients.

### Duplicate Consolidation Display

When multiple newsletters recommend the same item, the card shows "Recommended by N sources" in orange text. Tapping this (or pressing Enter on a selected recommendation) expands to show all sources:

```swift
struct RecommendationDetailView: View {
    let recommendation: Recommendation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title, creator, type
                // ...

                // All sources
                if let sources = recommendation.duplicateSources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recommended by \(sources.count + 1) sources")
                            .font(.headline)

                        // Original source
                        SourceCard(
                            newsletterName: recommendation.sourceNewsletterName,
                            date: recommendation.sourceDate,
                            contextSnippet: recommendation.contextSnippet
                        )

                        // Duplicate sources
                        ForEach(sources, id: \.newsletterName) { source in
                            SourceCard(
                                newsletterName: source.newsletterName,
                                date: source.date,
                                contextSnippet: source.contextSnippet
                            )
                        }
                    }
                } else {
                    // Single source -- show full context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From \(recommendation.sourceNewsletterName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(recommendation.contextSnippet)
                            .font(.body)
                    }
                }
            }
            .padding()
        }
    }
}
```

---

## 9. Compose and Reply

### Compose View

The compose view is a separate window on macOS and a full-screen sheet on iOS.

```swift
struct ComposeView: View {
    @Environment(AppState.self) private var appState
    @State private var draft = ComposeDraft()
    @State private var autoSaveTimer: Timer?
    @FocusState private var focusedField: ComposeField?

    enum ComposeField {
        case to, cc, subject, body
    }

    var body: some View {
        VStack(spacing: 0) {
            // Account picker
            HStack {
                Text("From:")
                    .foregroundStyle(.secondary)
                AccountPicker(selectedAccountID: $draft.fromAccountID)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Divider()

            // Recipients
            HStack {
                Text("To:")
                    .foregroundStyle(.secondary)
                TextField("Recipients", text: $draft.to)
                    .focused($focusedField, equals: .to)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Subject
            HStack {
                Text("Subject:")
                    .foregroundStyle(.secondary)
                TextField("Subject", text: $draft.subject)
                    .focused($focusedField, equals: .subject)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Body
            TextEditor(text: $draft.body)
                .focused($focusedField, equals: .body)
                .font(.body)
                .padding(.horizontal, 8)

            Divider()

            // Toolbar
            HStack {
                Button("Discard") { discardDraft() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Send") { sendEmail() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            focusedField = draft.isReply ? .body : .to
            startAutoSave()
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
        }
    }

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await saveDraft() }
        }
    }

    private func saveDraft() async {
        guard !draft.body.isEmpty || !draft.subject.isEmpty else { return }
        do {
            draft = try await apiClient.saveDraft(draft)
        } catch {
            // Silently fail -- auto-save should not interrupt the user
        }
    }

    private func sendEmail() {
        Task {
            do {
                try await apiClient.sendEmail(draft)
                // Close compose window/sheet
            } catch {
                // Show error
            }
        }
    }
}

struct ComposeDraft: Codable, Sendable {
    var id: String?               // Set after first server save
    var fromAccountID: String = ""
    var to: String = ""
    var cc: String = ""
    var bcc: String = ""
    var subject: String = ""
    var body: String = ""
    var inReplyTo: String?        // Message-ID of the email being replied to
    var isReply: Bool = false
}
```

### Account Selector

The account picker defaults to the account that received the email (for replies) or the user's primary account (for new compose). It shows the color-coded dot and account name.

```swift
struct AccountPicker: View {
    @Binding var selectedAccountID: String
    @Environment(AppState.self) private var appState

    var body: some View {
        Picker("Account", selection: $selectedAccountID) {
            ForEach(appState.accounts) { account in
                HStack {
                    Circle()
                        .fill(Color(hex: account.color))
                        .frame(width: 8, height: 8)
                    Text(account.emailAddress)
                }
                .tag(account.id)
            }
        }
        .labelsHidden()
    }
}
```

### Reply Flow

When replying (R key on macOS, reply button on iOS):

1. Create a `ComposeDraft` with `isReply = true`, `fromAccountID` set to the receiving account, `inReplyTo` set to the original email's message ID, and `to` set to the original sender's address.
2. Populate the body with a quoted version of the original email (the server can provide this as part of the email detail response, or the client can construct it from the text body).
3. Open the compose window/sheet with focus on the body field.
4. On send, POST to `/api/send`. The server handles SMTP delivery, In-Reply-To/References headers, sent mail archiving -- the client just sends the draft.

### Draft Auto-Save

Drafts auto-save to the server every 30 seconds while the user is composing. The server stores drafts and makes them available on other devices. The first save returns a draft ID, which subsequent saves use for updates.

If the server is unreachable, drafts are saved locally (UserDefaults or a local file) and synced when the connection returns.

### Rich Text vs Plain Text

For v1, compose in plain text. This keeps the implementation simple and aligns with the product philosophy ("User writes their own emails, usually a few sentences"). SwiftUI's TextEditor handles plain text well.

If rich text is needed later, options include:
- WKWebView with contenteditable for a web-based rich text editor
- A custom AttributedString editor
- A Markdown-to-HTML approach where the user writes Markdown and the server converts it

Plain text is the right starting point. Most personal email is short and does not need formatting.

---

## 10. Snooze UX

### Quick Picker Popup

When the user presses S (macOS) or taps the snooze button (iOS), a compact picker appears with preset options and a custom time option.

```swift
struct SnoozePickerView: View {
    let emailID: String
    @Binding var isPresented: Bool
    @Environment(EmailStore.self) private var store
    @State private var showCustomPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Snooze until...")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()

            SnoozeOption(
                icon: "clock",
                label: "2 Hours",
                detail: formattedTime(hoursFromNow: 2)
            ) {
                snooze(until: Date.now.addingTimeInterval(2 * 3600))
            }

            SnoozeOption(
                icon: "sunrise",
                label: "Tomorrow Morning",
                detail: formattedTomorrowMorning()
            ) {
                snooze(until: tomorrowMorning())
            }

            SnoozeOption(
                icon: "calendar",
                label: "Next Week",
                detail: formattedNextMonday()
            ) {
                snooze(until: nextMonday())
            }

            Divider()

            SnoozeOption(
                icon: "ellipsis.circle",
                label: "Pick a Date & Time",
                detail: ""
            ) {
                showCustomPicker = true
            }
        }
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
        .sheet(isPresented: $showCustomPicker) {
            CustomSnoozePicker(emailID: emailID, isPresented: $isPresented)
        }
    }

    private func snooze(until date: Date) {
        Task {
            await store.snooze(emailID, until: date)
            isPresented = false
        }
    }

    private func tomorrowMorning() -> Date {
        Calendar.current.nextDate(
            after: Date.now,
            matching: DateComponents(hour: 9, minute: 0),
            matchingPolicy: .nextTime
        )!
    }

    private func nextMonday() -> Date {
        Calendar.current.nextDate(
            after: Date.now,
            matching: DateComponents(weekday: 2, hour: 9, minute: 0),
            matchingPolicy: .nextTime
        )!
    }
}

struct SnoozeOption: View {
    let icon: String
    let label: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(label)
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

### Custom Date/Time Picker

The custom picker uses SwiftUI's DatePicker:

```swift
struct CustomSnoozePicker: View {
    let emailID: String
    @Binding var isPresented: Bool
    @State private var selectedDate = Date.now.addingTimeInterval(3600)
    @Environment(EmailStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            Text("Snooze until")
                .font(.headline)

            DatePicker(
                "Return date",
                selection: $selectedDate,
                in: Date.now...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Snooze") {
                    Task {
                        await store.snooze(emailID, until: selectedDate)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 320)
    }
}
```

### Snoozed Items Display in Action Queue

Snoozed items that have returned appear at the top of the Action Queue with a visual badge:

```swift
struct EmailRowView: View {
    let email: Email

    var body: some View {
        HStack(spacing: 12) {
            AccountDot(accountID: email.accountID)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(email.from.name ?? email.from.email)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    Text(email.receivedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(email.subject)
                    .lineLimit(1)

                Text(email.snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Snooze badge
            if let snooze = email.snoozeState {
                VStack(spacing: 2) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(.orange)
                    if snooze.snoozeCount > 1 {
                        Text("\(snooze.snoozeCount)x")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

The snooze badge shows:
- A clock icon in orange for any snoozed-and-returned email
- A counter ("2x", "3x") if the email has been snoozed multiple times
- The counter serves as a gentle accountability signal -- "you have been deferring this"

### Multi-Snooze Counter

The top of the Action Queue view shows a summary banner when there are returned snoozed items:

```swift
struct SnoozeReturnBanner: View {
    let returnedCount: Int

    var body: some View {
        if returnedCount > 0 {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("\(returnedCount) snoozed item\(returnedCount == 1 ? "" : "s") returned")
                    .font(.subheadline)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
        }
    }
}
```

---

## 11. Real-Time Updates

### WebSocket Connection Lifecycle

```
App Launch
    |
    v
[Server Discovery] --> Find server URL
    |
    v
[REST: Fetch initial data] --> Populate stores
    |
    v
[WebSocket: Connect] --> Start receiving events
    |
    v
[Event loop] --> Route events to stores --> UI updates
    |
    +--> [Connection lost] --> Show offline banner
    |       |
    |       v
    |    [Exponential backoff reconnect]
    |       |
    |       v
    |    [Reconnected] --> REST: Fetch changes since last sync
    |       |                   |
    |       v                   v
    |    [WebSocket: Reconnect] --> Resume event loop
    |
    +--> [App backgrounded (iOS)]
    |       |
    |       v
    |    [Disconnect WebSocket] --> Save last sync timestamp
    |
    +--> [App foregrounded (iOS)]
            |
            v
         [REST: Fetch changes since last sync]
            |
            v
         [WebSocket: Reconnect]
```

### How New Emails Appear Without Full Refresh

1. Server classifies a new email.
2. Server broadcasts a `new_email` WebSocket event containing the full `Email` struct.
3. The client's event router receives the event.
4. `EmailStore.handleEvent(.newEmail(email))` inserts the email into the appropriate array based on its classification.
5. Because `EmailStore` is `@Observable`, any view reading from the affected array re-renders automatically.
6. The new email appears in the list with an animation (SwiftUI's implicit list animation handles this).

No polling. No full refresh. The email appears within milliseconds of the server processing it.

### How Classification Changes Update the UI

If the server reclassifies an email (or the user reclassifies from another device):

1. Server broadcasts `email_updated` with the updated `Email` struct.
2. `EmailStore` removes the email from its old queue array and inserts it into the new queue array.
3. The email disappears from one list and appears in another.

### How Snooze Returns Trigger UI Updates

1. The server's snooze scheduler detects that a snoozed email's return time has passed.
2. Server broadcasts `snooze_return` with the email.
3. `EmailStore` inserts the email at the top of `actionQueue`.
4. The SnoozeReturnBanner updates its count.
5. On iOS, if the user granted notification permission, a local notification fires.

### Heartbeat / Keep-Alive

The WebSocket connection should send a ping every 30 seconds to detect stale connections. If a ping fails (no pong within 10 seconds), consider the connection lost and start the reconnect loop.

```swift
// In the AppCoordinator, start a heartbeat task
private func startHeartbeat() {
    heartbeatTask = Task {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            await webSocket.sendPing()
        }
    }
}
```

---

## 12. Offline Behavior

### What Happens When the Server is Unreachable

1. **Detection:** The API client gets a connection error on a REST call, or the WebSocket connection drops.
2. **UI indicator:** An `OfflineBanner` appears at the top of the screen: "Server unreachable. Showing cached data. Actions will sync when connected."
3. **Read-only mode:** The user can still browse cached emails, read cached email bodies, and browse cached recommendations.
4. **Queued actions:** User actions (archive, snooze, reclassify, send) are queued locally.
5. **Reconnection polling:** The app checks server reachability every 15 seconds.
6. **Reconnection:** When the server becomes reachable, flush the action queue (in order), do a REST fetch to get any missed updates, and reconnect the WebSocket.

### Local Caching Strategy

The client maintains a lightweight local cache for offline viewing. This is not a full database -- it is a simple cache of recently fetched data.

**What to cache:**
- Email lists for each view (the most recent page of each)
- Email detail bodies for recently viewed emails (LRU, max ~100 emails)
- Recommendations list
- Latest digest
- Account list

**Storage mechanism options:**
1. **SwiftData / Core Data:** Full persistence with query support. Probably overkill for a cache.
2. **FileManager + Codable:** Write JSON files to the app's cache directory. Simple, no dependencies.
3. **UserDefaults:** For small data (accounts, last sync timestamp). Not for email lists.

**Recommended approach:** Use `FileManager` with `Codable` serialization for the cache. Write each data set (action queue emails, reading queue emails, etc.) as a JSON file in the app's caches directory. On launch, load from cache first, then fetch from server. This gives instant UI on cold launch even before the server responds.

```swift
actor LocalCache {
    private let cacheDir: URL

    init() {
        self.cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EmailClientCache")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func save<T: Encodable>(_ data: T, key: String) throws {
        let url = cacheDir.appendingPathComponent("\(key).json")
        let encoded = try JSONEncoder.apiEncoder.encode(data)
        try encoded.write(to: url)
    }

    func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        let url = cacheDir.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.apiDecoder.decode(T.self, from: data)
    }
}
```

### Action Queue for Offline Actions

When the user takes an action while offline, queue it locally and replay when the server is reachable:

```swift
struct PendingAction: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let action: ActionType

    enum ActionType: Codable, Sendable {
        case archive(emailID: String)
        case snooze(emailID: String, until: Date)
        case reclassify(emailID: String, classification: Email.Classification)
        case markRead(emailID: String)
        case updateRecommendationStatus(id: String, status: Recommendation.RecommendationStatus)
    }
}

actor OfflineActionQueue {
    private var pendingActions: [PendingAction] = []
    private let apiClient: APIClient
    private let cache: LocalCache

    func enqueue(_ action: PendingAction.ActionType) {
        let pending = PendingAction(id: UUID(), timestamp: .now, action: action)
        pendingActions.append(pending)
        // Persist to disk
        try? cache.save(pendingActions, key: "pending_actions")
    }

    func flush() async {
        let actions = pendingActions
        for action in actions {
            do {
                try await execute(action)
                pendingActions.removeAll { $0.id == action.id }
            } catch {
                // If an action fails, stop flushing -- process in order
                break
            }
        }
        try? cache.save(pendingActions, key: "pending_actions")
    }

    private func execute(_ action: PendingAction) async throws {
        switch action.action {
        case .archive(let id):
            try await apiClient.archiveEmail(id: id)
        case .snooze(let id, let until):
            try await apiClient.snoozeEmail(id: id, until: until)
        case .reclassify(let id, let classification):
            try await apiClient.reclassifyEmail(id: id, newClassification: classification)
        case .markRead(let id):
            try await apiClient.markRead(id: id)
        case .updateRecommendationStatus(let id, let status):
            try await apiClient.updateRecommendationStatus(id: id, status: status)
        }
    }
}
```

### Offline Indicator in UI

```swift
struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Offline -- showing cached data")
                .font(.subheadline)
            Spacer()
            ProgressView()
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.15))
        .foregroundStyle(.orange)
    }
}
```

Place this at the top of the ContentView when `appState.isOnline == false`. On iOS, use a similar banner or modify the navigation title to indicate offline status.

---

## 13. Account Switching and Filtering

### Unified View by Default

All email views (Action Queue, Reading Queue, etc.) show emails from all three accounts by default, interleaved by date. The account is identified by a color-coded dot next to each email.

### Account Color Mapping

```swift
struct AccountDot: View {
    let accountID: String
    @Environment(AppState.self) private var appState

    var body: some View {
        Circle()
            .fill(accountColor)
            .frame(width: 8, height: 8)
    }

    private var accountColor: Color {
        guard let account = appState.accounts.first(where: { $0.id == accountID }) else {
            return .gray
        }
        return Color(hex: account.color)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

Default colors from the brief:
- Work: Blue (`#3B82F6`)
- Personal 1: Green (`#22C55E`)
- Personal 2: Orange (`#F97316`)

### Filter Toggle

The account filter is a global state on `AppState.accountFilter`. When set, all email list views filter their displayed emails accordingly.

**macOS shortcuts:**
- Cmd+Shift+1: Work only
- Cmd+Shift+2: Personal only
- Cmd+Shift+3: All accounts (reset filter)

**macOS UI:** A segmented control or dropdown in the toolbar area of the email list:

```swift
struct AccountFilterToolbar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Picker("Account", selection: $state.accountFilter) {
            Text("All").tag(AccountFilter.all)
            ForEach(appState.accounts) { account in
                HStack {
                    Circle()
                        .fill(Color(hex: account.color))
                        .frame(width: 8, height: 8)
                    Text(account.name)
                }
                .tag(AccountFilter.specific(account.id))
            }
        }
        .pickerStyle(.segmented)
    }
}
```

**iOS UI:** A menu button in the navigation bar toolbar:

```swift
struct AccountFilterMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Menu {
            Button("All Accounts") { state.accountFilter = .all }
            Divider()
            ForEach(appState.accounts) { account in
                Button {
                    state.accountFilter = .specific(account.id)
                } label: {
                    HStack {
                        Circle()
                            .fill(Color(hex: account.color))
                            .frame(width: 8, height: 8)
                        Text(account.name)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}
```

### Filtering Implementation

The filter is applied at the view level, not the API level. Since the stores hold all emails, the view filters them for display:

```swift
// In any email list view
var displayedEmails: [Email] {
    let allForView = store.emails(for: currentView)
    switch appState.accountFilter {
    case .all:
        return allForView
    case .accountType(let type):
        let matchingAccountIDs = appState.accounts
            .filter { $0.type == type }
            .map(\.id)
        return allForView.filter { matchingAccountIDs.contains($0.accountID) }
    case .specific(let accountID):
        return allForView.filter { $0.accountID == accountID }
    }
}
```

Alternatively, the filter could be passed to the server API as a query parameter, which would reduce data transfer if the email volume per view is large. For a personal client with 3 accounts and moderate volume, client-side filtering of already-fetched data is simple and responsive.

### Account Filter Persistence

The account filter resets to "All" on app launch. It is a transient session-level preference, not a persistent setting. The user selects it when they want to focus on one account, and it resets naturally when the app restarts. If users request persistence, store it in UserDefaults.

---

## Summary of Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Client architecture | Thin API consumer | Server handles all heavy lifting; client is fast and simple |
| Shared code | Swift Package (EmailClientKit) | Models, networking, cache shared between macOS and iOS |
| Platform targets | Separate macOS and iOS targets | Platform-specific UI is too different for a single target |
| State management | @Observable stores | Modern, performant, minimal boilerplate |
| Networking | URLSession async/await | No dependencies needed; built-in HTTP and WebSocket support |
| Real-time updates | WebSocket from server | Immediate UI updates without polling |
| Email rendering | WKWebView with JS disabled | Security-first; WebKit handles HTML email well |
| Local cache | FileManager + Codable JSON | Simple, no database dependency for a cache layer |
| Keyboard system | Commands (Cmd+key) + onKeyPress (single-key) | Layered approach matching Apple's SwiftUI capabilities |
| Navigation (macOS) | NavigationSplitView, 3 columns | Apple's standard for sidebar-driven apps |
| Navigation (iOS) | TabView + NavigationStack | Tab bar provides persistent access to all views |
| Compose | Plain text, separate window (macOS) / sheet (iOS) | Simple; rich text can be added later |
| Offline | Cache + action queue | Read cached data offline, replay actions on reconnect |

### Critical Path for Implementation

1. **Define the Go server API contract first.** Agree on JSON shapes, endpoint paths, and WebSocket event types. The Swift models mirror this exactly. Changes to the API contract require changes to the Swift models, so stability here is critical.

2. **Build EmailClientKit package with models and API client.** This is the foundation both apps depend on. Write thorough tests for encoding/decoding, especially date handling and edge cases (nil fields, empty arrays).

3. **Build the macOS app first.** It is the primary platform. Start with the NavigationSplitView shell, email list, and email detail. Get the REST fetch -> display flow working end-to-end.

4. **Add WebSocket integration.** Connect to the server, receive events, update stores. Verify that new emails appear without manual refresh.

5. **Build the keyboard system.** Start with Cmd+1-5 view switching (easy, Commands system). Then add J/K navigation (onKeyPress). Then build the command palette. Test focus management extensively.

6. **Build the iOS app.** With the shared package already working, the iOS app is primarily layout work. TabView, NavigationStack, swipe gestures, pull-to-refresh.

7. **Add offline support.** Cache layer, action queue, offline banner. Test by disconnecting the server during use.

8. **Polish.** Snooze picker animations, recommendation card layout, newsletter reader typography, dark mode email rendering.
