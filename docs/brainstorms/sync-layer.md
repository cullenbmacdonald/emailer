# Sync Layer Technology Brainstorm

## Context and Requirements

We are building a personal email client (macOS + iOS) with a hub-and-spoke architecture:

- **Mac Mini (hub)**: Always-on, pulls email via IMAP, runs local AI classification, generates digests
- **Other devices (spokes)**: MacBook, iPhone, iPad -- display decisions, allow user overrides
- **Devices do NOT reprocess emails** -- they consume decisions from the hub

### Data to Sync

| Data Type | Direction | Frequency | Size | Latency Tolerance |
|-----------|-----------|-----------|------|-------------------|
| Classification decisions | Hub -> Devices | Per email arrival | Small (enum + metadata) | Seconds acceptable |
| Extracted recommendations | Hub -> Devices | Per newsletter processed | Medium (title, context, links) | Minutes acceptable |
| Snooze states / return times | Bidirectional | On user action | Small (timestamp + email ref) | Seconds preferred |
| User overrides / training signals | Devices -> Hub | On user action | Small (override + context) | Seconds preferred |
| Daily digest content | Hub -> Devices | 2x daily (6am, 7pm) | Medium (rendered digest) | Minutes acceptable |
| Read/archive/interaction state | Bidirectional | On user action | Small (status enum) | Seconds preferred |

### Key Constraints

- All Apple ecosystem (macOS + iOS)
- Single user, multiple personal devices (3-5 devices)
- Mac Mini is always on and always authoritative for AI decisions
- Privacy is paramount -- no third-party cloud services preferred
- Must work both on local network (home) and remotely (away from home)
- The sync layer must eventually be extensible for future modules (calendar, tasks, etc.)

---

> **⚠️ Architecture Update**: This document was written before the final architecture was decided. The sync layer is now the **Go server itself** — clients connect directly via REST + WebSocket API, with Tailscale for remote access. CloudKit, P2P, CRDTs, and Hummingbird (Swift server) are not used. The data model designs, conflict resolution analysis, and sync record schemas in this document remain valuable reference — but the technology recommendations have been superseded. See `go-server-architecture.md` for the current sync/API design.

---

## 1. CloudKit

### How It Works

CloudKit is Apple's cloud backend framework, providing a structured database (not just file storage) accessible from any Apple device signed into the same iCloud account. It operates in three database scopes:

- **Private Database**: Per-user data, only visible to that user. This is what we would use.
- **Public Database**: Shared across all users. Not relevant here.
- **Shared Database**: For sharing records between users. Not relevant for single-user.

**CKRecord** is the fundamental unit -- essentially a dictionary of key-value pairs with a record type, record ID, and metadata (creation date, modification date, change tags). Records live in **zones** within a database. Custom zones allow atomic batch saves and efficient change tracking.

**CKSubscription / CKSyncEngine** provide real-time push notification when records change on the server. Since iOS 17, Apple provides **CKSyncEngine**, which is a purpose-built sync coordinator that handles:

- Scheduling sync according to system conditions
- Setting up and managing push subscriptions automatically
- Creating CKOperation instances for data transport
- Managing server change tokens for incremental sync
- Coalescing changes for efficiency

CKSyncEngine replaces the need to manually manage CKSubscription, CKFetchRecordZoneChangesOperation, and CKModifyRecordsOperation. It is now the recommended approach.

### Conflict Resolution

CloudKit uses **change tags** (optimistic concurrency). When a client tries to save a record, the server checks the change tag against the current version. If they differ, CloudKit returns a `CKError` containing three records:

1. **Client record**: What you tried to save
2. **Server record**: What is currently on the server
3. **Ancestor record**: The last version both sides agreed on

This enables three-way merge. You inspect which fields changed on each side and decide how to merge. The default behavior is "last writer wins" but custom resolution is fully supported.

For our use case, conflict resolution is straightforward because:
- Classification decisions flow one direction (hub -> devices) -- no conflict possible
- User overrides are "last action wins" semantics -- the most recent user action is correct
- Snooze states are "last action wins" -- if you snooze on your phone then unsnooze on your Mac, the latest action is what you want

### Pros

- **Free**: Included with Apple Developer account. Private database gets 10 GB storage, which is vastly more than we need for metadata sync (no email bodies stored here)
- **No server to maintain**: Apple handles infrastructure, scaling, availability
- **Built-in push notifications**: CKSyncEngine handles real-time updates across devices
- **Offline support**: Apps can queue changes while offline; CloudKit syncs when connectivity returns
- **Native integration**: First-class support in Swift, SwiftUI, and Xcode
- **Privacy**: Data stays in user's iCloud account; Apple cannot read private database contents
- **Already solves auth**: iCloud sign-in handles device identity

### Cons

- **Apple-only**: If we ever wanted an Android or web client, CloudKit is a dead end
- **Limited query capabilities**: No JOINs, no complex queries. Must manually add queryable indexes to fields. Queries are limited to simple predicates on indexed fields
- **Debugging is painful**: CloudKit Console is clunky. Private database records require "Act As iCloud Account" to inspect. Developers report records appearing synced but showing "No Records Found" in the console
- **Opaque sync timing**: You cannot control when sync happens. CKSyncEngine schedules based on system conditions (battery, network, system load). Can be seconds or minutes
- **Schema deployment issues**: Developers have reported "Internal Error" when deploying schemas to production
- **No server-side logic**: Cannot run code on CloudKit's servers. All logic must be on-device or on the Mac Mini
- **Rate limits and quotas**: While generous for our scale, CloudKit has per-app rate limits that are not well documented
- **iOS 17+ required for CKSyncEngine**: Older devices would need the manual CKSubscription approach

### Fit for Our Use Case

CloudKit is a strong candidate for the device-to-device sync portion. The data patterns fit well:

- Small records (classification metadata, snooze times, override signals)
- Low write frequency (per email arrival, not per second)
- Single user, multiple devices -- exactly CloudKit's sweet spot
- Hub-and-spoke with mostly one-directional flow simplifies conflict resolution

**However**, there is an architectural tension: the Mac Mini is the authoritative source, but CloudKit treats all devices as equal peers. We would need to design the data model so the Mac Mini writes classification records, and other devices only write override/snooze records. This is achievable but requires discipline.

**Verdict**: CloudKit is viable as the primary sync mechanism. The debugging pain is real but manageable given our simple data model.

---

## 2. Custom Server (Self-Hosted)

### Architecture: Mac Mini as the Server

Since the Mac Mini is already always-on and running AI classification, the most natural custom-server approach is to run the sync server directly on the Mac Mini itself. This eliminates the need for any external hosting.

```
Mac Mini
+-----------------------------------+
|  IMAP Poller                      |
|  AI Classification Engine         |
|  Sync Server (API + WebSocket)    |
|  SQLite Database                  |
+-----------------------------------+
        |           |
    Local WiFi    Remote (Tailscale/Cloudflare)
        |           |
   iPhone/iPad    MacBook (away from home)
```

### Server Framework Options

**Vapor (Swift)**
- Most mature Swift server framework. Built on SwiftNIO
- Full ORM (Fluent), WebSocket support, middleware, auth
- Pro: Shared Swift codebase with iOS/macOS app. Same models, same Codable types
- Pro: Large community, extensive documentation
- Con: Heavy dependency tree, longer compile times
- Con: Vapor 5 (structured concurrency rewrite) is in progress but not stable yet

**Hummingbird (Swift)**
- Lightweight alternative to Vapor. Also built on SwiftNIO
- Minimal dependencies, modular design -- include only what you need
- Pro: Faster compilation, smaller binary, modern async/await throughout (v2)
- Pro: Perfect for a focused sync API with few endpoints
- Con: Smaller community, fewer tutorials
- Con: Less battle-tested in production

**Go**
- Excellent for small, focused services. Single binary deployment
- Pro: Extremely fast compilation, tiny memory footprint, built-in HTTP server
- Pro: Goroutines make WebSocket handling trivial
- Con: Separate language from the rest of the codebase. No shared types with Swift
- Con: Would need to maintain data model definitions in two languages

**Rust (Axum/Actix)**
- Maximum performance, memory safety
- Pro: If we ever need high throughput, Rust handles it effortlessly
- Con: Steep learning curve, slowest compilation
- Con: Completely separate ecosystem from Swift. Overkill for this use case

**Recommendation**: Hummingbird (Swift). For a focused sync API serving 3-5 devices, its lightweight nature is ideal. Shared Swift types with the client apps eliminate serialization mismatches. If we find ourselves needing more features, migrating to Vapor is straightforward since both are SwiftNIO-based.

### Database Options

**SQLite (with or without Litestream)**
- Single file, zero configuration, embedded in the server process
- More than sufficient for our scale (single user, thousands of emails, not millions)
- Litestream can continuously replicate the SQLite WAL to S3-compatible storage for backup
- Pro: Simplest possible setup. No separate database server
- Pro: Litestream gives us disaster recovery with near-zero overhead
- Pro: GRDB.swift provides an excellent Swift interface with observation/reactive patterns
- Con: Single writer at a time (fine for our scale)
- Con: No built-in replication to other nodes (but we do not need that)

**PostgreSQL**
- Full relational database with ACID, complex queries, LISTEN/NOTIFY for real-time
- Pro: Powerful querying for future analytics on email patterns
- Pro: LISTEN/NOTIFY could drive WebSocket pushes natively
- Con: Separate process to manage. Overkill for single-user metadata storage
- Con: More resource usage on the Mac Mini alongside AI models

**Recommendation**: SQLite with GRDB.swift and Litestream for backup. It is the simplest correct solution for our scale. The Mac Mini's AI models are the resource-intensive workload; the sync database should be as lightweight as possible.

### Communication Protocol

**REST (HTTP)**
- Simple request/response. Easy to debug with curl or any HTTP client
- Pro: Universal, well-understood, easy to cache
- Con: Requires polling for updates, or a separate push mechanism
- Con: Overhead of HTTP headers on every request

**WebSocket**
- Persistent bidirectional connection. Server pushes changes instantly
- Pro: Real-time updates without polling. Low latency
- Pro: iOS URLSessionWebSocketTask provides native support
- Con: Connection management (reconnection, heartbeat) adds complexity
- Con: Not great through some corporate proxies

**gRPC**
- Binary protocol (Protocol Buffers) over HTTP/2. Supports streaming
- Pro: Strongly typed contracts. Efficient serialization
- Pro: Server streaming fits our hub-to-device push pattern
- Con: Heavier setup. Proto file management
- Con: Limited native iOS support (grpc-swift exists but adds dependency weight)
- Con: Overkill for 3-5 devices

**Recommendation**: REST for initial data fetch + WebSocket for real-time push. This hybrid is pragmatic:

1. Device connects, does a REST GET to fetch current state (all classifications since last sync)
2. Opens a WebSocket connection for live updates
3. User actions (overrides, snoozes) sent via REST POST
4. Server broadcasts changes to all connected WebSocket clients

This gives us the simplicity of REST for CRUD operations with the immediacy of WebSocket for push.

### Remote Access (Away from Home)

The Mac Mini is on a home network. When devices are away, they need to reach it. Options:

**Tailscale (WireGuard-based mesh VPN)**
- Creates a private encrypted network between your devices
- Pro: Zero-config, works through NAT and firewalls, no port forwarding needed
- Pro: Free for personal use (up to 100 devices)
- Pro: All traffic encrypted, no exposure to public internet
- Con: Requires Tailscale client on each device (available for iOS and macOS)

**Cloudflare Tunnel**
- Exposes local server to internet through Cloudflare's network
- Pro: No port forwarding, DDoS protection, SSL termination
- Con: Traffic routes through Cloudflare (privacy consideration)
- Con: Requires Cloudflare account and domain

**Direct Port Forwarding + Dynamic DNS**
- Traditional approach: forward port on router, use dynamic DNS for stable URL
- Pro: No third-party dependencies
- Con: Security risk (server exposed to internet), requires router configuration

**Recommendation**: Tailscale. It is purpose-built for this exact scenario -- accessing a home server from mobile devices. The free tier is more than sufficient. All traffic stays encrypted on a private mesh network. No public exposure.

### Pros of Custom Server Approach

- **Full control**: We define the API, the data model, the conflict resolution, everything
- **Mac Mini already exists**: No new infrastructure needed
- **Shared Swift codebase**: Server and clients can share model definitions
- **Extensible**: Easy to add endpoints for future modules (calendar, tasks)
- **No vendor dependency**: Works regardless of Apple's iCloud changes

### Cons of Custom Server Approach

- **More to build**: API endpoints, WebSocket handling, auth, error handling
- **More to maintain**: Server uptime, backups, updates
- **Mac Mini single point of failure**: If it goes down, no sync (mitigated by offline-first client design)
- **Remote access setup**: Need Tailscale or similar for out-of-home access
- **Security responsibility**: We handle auth and encryption ourselves

---

## 3. Peer-to-Peer / Local Network

### Multipeer Connectivity Framework

Apple's framework for discovering and communicating with nearby devices. Uses a combination of infrastructure WiFi, peer-to-peer WiFi, and Bluetooth.

**Key components:**
- `MCNearbyServiceAdvertiser`: Broadcasts the device's presence on the network
- `MCNearbyServiceBrowser`: Discovers other devices running the same app
- `MCSession`: Manages the connection and data exchange between peers

**Data exchange supports:**
- Message-based data (small payloads, like our classification records)
- Streaming data (continuous data flow)
- Resource transfer (file-based, with progress tracking)

### Bonjour / mDNS

Lower-level service discovery. The Mac Mini advertises a service (e.g., `_emailsync._tcp`) on the local network. Other devices discover it via Bonjour browsing.

Since iOS 14, apps must declare `NSLocalNetworkUsageDescription` and `NSBonjourServices` in Info.plist, and the user sees a permission prompt for local network access.

Modern implementation uses Network.framework:
- `NWBrowser` for discovering services
- `NWListener` for advertising services
- `NWConnection` for establishing connections

This is lower-level than Multipeer Connectivity but gives more control over the protocol.

### How It Would Work for Our Case

```
Mac Mini advertises: _emailsync._tcp on local network
     |
     +-- iPhone discovers via Bonjour, connects, receives updates
     +-- iPad discovers via Bonjour, connects, receives updates
     +-- MacBook discovers via Bonjour, connects, receives updates
```

The Mac Mini would run a lightweight TCP server alongside its AI processing. When devices are on the same network, they discover it automatically and sync directly -- no internet required. This would be extremely fast (sub-millisecond latency on local network).

### Pros

- **No cloud dependency**: Works with no internet connection at all
- **Extremely fast**: Local network latency is negligible
- **Private**: Data never leaves the local network
- **Automatic discovery**: Devices find each other without configuration
- **Native Apple support**: First-class framework support on iOS and macOS

### Cons

- **Does not work remotely**: When you leave home with your iPhone, sync stops entirely
- **Bluetooth range limitations**: If using Bluetooth transport, limited to about 10 meters
- **Complex connection management**: Devices appear, disappear, reconnect. The framework gives you events but you handle the state machine
- **iOS background limitations**: iOS aggressively suspends background networking. An app in the background cannot maintain a persistent Multipeer Connectivity session. Bonjour browsing also gets restricted
- **Local network permission prompt**: iOS shows a permission dialog. Some users decline without understanding why

### Fit for Our Use Case

Peer-to-peer alone is insufficient because the system must work when you leave the house with your phone. However, as a **supplement** to another sync mechanism, local network sync is valuable:

- When at home, sync happens instantly over the local network
- When away, fallback to CloudKit or the custom server over Tailscale

The iOS background limitations are a real problem. You cannot rely on Multipeer Connectivity for reliable background sync -- it works when the app is in the foreground but gets killed in the background.

**Verdict**: Useful as an optimization layer, not as the primary sync mechanism.

---

## 4. CRDTs (Conflict-Free Replicated Data Types)

### What Are CRDTs?

CRDTs are data structures designed so that any two replicas can be merged without conflicts, regardless of the order operations arrive. They achieve this through mathematical properties that guarantee convergence -- all replicas will eventually reach the same state as long as all operations are eventually delivered.

Two main categories:

**State-based CRDTs (CvRDTs)**: Each replica maintains its full state. To sync, replicas exchange their entire state and merge using a deterministic merge function. The merge function must be commutative, associative, and idempotent.

**Operation-based CRDTs (CmRDTs)**: Replicas exchange operations (deltas) rather than full state. Operations must be commutative -- the order they arrive does not matter.

Common CRDT types:
- **G-Counter**: Only increments. Each node tracks its own count; total is the sum
- **PN-Counter**: Supports increment and decrement via two G-Counters
- **LWW-Register (Last Writer Wins)**: Stores a single value with a timestamp. Latest timestamp wins
- **OR-Set (Observed-Remove Set)**: Add and remove elements. Add wins over concurrent remove
- **LWW-Map**: Map where each key is an LWW-Register

### Swift CRDT Libraries

**heckj/CRDT** (most maintained)
- Implements delta-state CRDTs as Swift generics
- Supports: GCounter, PNCounter, LWWRegister, ORSet, ORMap
- Requires iOS 13+
- Delta-state replication for efficient sync (send only changes, not full state)
- Last active development approximately one year ago

**bdewey/KeyValueCRDT**
- Key-value store backed by SQLite, using CRDT semantics
- Designed for iCloud Documents sync
- Useful if you want file-based sync with CRDT conflict resolution

### Are CRDTs Appropriate for Our Use Case?

Let us evaluate each data type against CRDT patterns:

**Classification decisions (hub -> devices)**
- Unidirectional. No conflict possible. CRDT is unnecessary overhead
- A simple "latest from hub" model works

**User overrides (devices -> hub)**
- LWW-Register is a natural fit. User taps "this is not spam" -- the last override wins
- But LWW-Register is trivially implementable without a CRDT library: just compare timestamps

**Snooze states**
- LWW-Register again. The last snooze/unsnooze action is the correct state
- Same argument: a timestamp comparison is sufficient

**Recommendations (hub -> devices, status changes bidirectional)**
- Status changes (New -> Saved -> Done -> Dismissed) are mostly single-actor
- Could use LWW-Register for status field
- Duplicate consolidation is a hub-side operation, not a sync conflict

**Read/archive state**
- LWW-Register. If you archive on your phone and someone "unarchives" on your Mac... wait, it is single-user. So the latest action is always correct

### Assessment

CRDTs solve a problem we mostly do not have. The challenging cases for CRDTs are:

1. Multiple actors concurrently editing the same field (collaborative text editing, shared counters)
2. Network partitions where operations accumulate on both sides and must merge

Our system has:
- A single authoritative hub for AI decisions (no conflict)
- A single user making overrides (the latest action is correct)
- LWW semantics that can be implemented with a simple timestamp comparison

Using a full CRDT library would add dependency weight and conceptual overhead for a problem that reduces to "keep the record with the latest timestamp."

**That said**, if the system eventually grows to include shared/collaborative features (multiple users managing a shared inbox), CRDTs would become genuinely valuable. The heckj/CRDT library would be the place to start.

**Verdict**: Not needed now. The data patterns are simple enough that LWW with timestamps handles all our conflict cases. Worth revisiting if the architecture expands to multi-user.

---

## 5. Hybrid Approaches

### Option A: CloudKit Primary + Local Network Optimization

```
Remote: CloudKit (automatic)
Local:  Bonjour direct connection to Mac Mini (fast path)
```

- Mac Mini writes decisions to CloudKit AND serves them over local network
- When devices are on the same WiFi, they discover the Mac Mini via Bonjour and sync directly (sub-second latency)
- When devices are away, CloudKit handles sync (seconds-to-minutes latency)
- User overrides go to CloudKit regardless (ensuring the hub picks them up even if the user overrides from outside the house)

**Pros:**
- Best of both worlds: fast local sync, reliable remote sync
- No external server infrastructure needed beyond iCloud
- Graceful degradation: if CloudKit is slow, local sync fills the gap

**Cons:**
- Two sync paths means two sets of logic to maintain
- Must handle deduplication (device might receive the same update from both paths)
- CloudKit's debugging issues still apply for the remote path
- Apple-only forever

### Option B: Mac Mini as Server + Tailscale for Remote

```
Local:  Direct HTTP/WebSocket to Mac Mini on local IP
Remote: Same HTTP/WebSocket to Mac Mini via Tailscale VPN
```

- Mac Mini runs the sync server (Hummingbird + SQLite)
- On local network, devices connect to `mac-mini.local:8080`
- Away from home, devices connect via Tailscale to `100.x.x.x:8080` (same server, different route)
- No CloudKit involved at all

**Pros:**
- Single sync path: same API, same logic, regardless of network
- Full control over data model, queries, conflict resolution
- No Apple cloud dependency
- Tailscale handles the local-vs-remote routing transparently
- Simpler mental model: one server, one database, one API

**Cons:**
- Mac Mini is a single point of failure. If it is off or unreachable, no sync
- Requires Tailscale on all devices
- Must implement offline queue on devices for when Mac Mini is unreachable
- Must handle server security (auth, TLS)

### Option C: Mac Mini as Server + CloudKit as Backup/Fallback

```
Primary:  Mac Mini server (always preferred when reachable)
Fallback: CloudKit (when Mac Mini is unreachable)
```

- Mac Mini is the primary sync server (same as Option B)
- Mac Mini also writes critical state to CloudKit as a backup
- If a device cannot reach the Mac Mini (down, network issue), it falls back to reading from CloudKit
- User overrides go to Mac Mini if reachable, CloudKit if not. Mac Mini polls CloudKit for overrides it missed

**Pros:**
- Resilience: Mac Mini outage does not mean total sync failure
- CloudKit is a passive backup, not the primary path (avoids debugging pain)
- Gradual migration path: start with CloudKit-only, add Mac Mini server later

**Cons:**
- Most complex to build: two sync targets, fallback logic, dedup
- Must keep CloudKit and local database in sync
- Complexity may not be justified for a single-user app

### Option D: CloudKit Only (Simplest)

```
All sync through CloudKit. Period.
```

- Mac Mini writes to CloudKit after processing each email
- All devices read from CloudKit
- User overrides written to CloudKit, Mac Mini picks them up

**Pros:**
- Simplest to implement
- No custom server code
- Works everywhere with iCloud
- CKSyncEngine handles most complexity

**Cons:**
- Sync latency is not controllable (system-scheduled)
- Debugging is harder
- Apple-only forever
- No server-side logic possible

### Recommendation

**Option B (Mac Mini as Server + Tailscale)** is the strongest choice for this project, with a path to Option C if resilience becomes a concern.

Reasoning:

1. **The Mac Mini already exists and is already the hub.** Adding a lightweight HTTP server to it is a small incremental step. It already has the database of classifications.

2. **Single sync path is simpler than dual sync paths.** Option A and C both require maintaining two sync mechanisms and handling dedup. This is disproportionate complexity for a single-user app.

3. **Full control matters for this app.** Email classification is the core value proposition. Being able to query, debug, and iterate on the sync data model without fighting CloudKit's limitations is valuable.

4. **Tailscale solves the remote access problem cleanly.** It is free, encrypted, and requires zero network configuration. The Tailscale app runs on iOS and macOS.

5. **Offline-first client design mitigates the single point of failure.** Devices cache all data locally. If the Mac Mini is unreachable, the app works with cached data and queues changes for when connectivity returns. This is the correct design regardless of sync mechanism.

6. **CloudKit remains available as a future option** if we want to add it as a backup layer later. Nothing about Option B prevents that.

---

## 6. Data Model Design for Sync

### Core Records

#### EmailClassification

The primary record written by the hub after processing each email.

```swift
struct EmailClassification: Codable, Identifiable {
    let id: UUID                          // Stable identifier for this classification
    let messageId: String                 // Email Message-ID header (RFC 2822)
    let accountId: String                 // Which email account (work, personal1, personal2)
    let classification: Classification    // The AI decision
    let confidence: Double                // 0.0-1.0, how confident the model is
    let summary: String?                  // AI-generated one-line summary
    let senderEmail: String
    let senderName: String?
    let subject: String
    let receivedAt: Date                  // When the email arrived
    let processedAt: Date                 // When the hub classified it
    let version: Int                      // Incremented on any update
    let isRead: Bool
    let isArchived: Bool

    enum Classification: String, Codable {
        case actionRequired    // -> Action Queue
        case newsletter        // -> Reading Queue
        case filtered          // -> Filtered (spam/marketing)
        case transactional     // -> Auto-archived
    }
}
```

#### UserOverride

Written by any device when the user reclassifies an email.

```swift
struct UserOverride: Codable, Identifiable {
    let id: UUID
    let classificationId: UUID            // References EmailClassification.id
    let previousClassification: Classification
    let newClassification: Classification
    let overriddenAt: Date                // Timestamp for LWW resolution
    let deviceId: String                  // Which device made the override
    let isTrainingSignal: Bool            // Should the AI learn from this?
}
```

The hub processes overrides as training signals: "The user moved this from 'filtered' to 'actionRequired', so emails like this should be classified as actionRequired in the future."

#### SnoozeState

```swift
struct SnoozeState: Codable, Identifiable {
    let id: UUID
    let classificationId: UUID            // References EmailClassification.id
    let snoozedAt: Date
    let returnAt: Date                    // When to resurface (stored in UTC)
    let returnAtTimeZone: String          // IANA timezone of the device that set it
    let snoozeCount: Int                  // How many times this email has been snoozed
    let isActive: Bool                    // false = cancelled or returned
    let deviceId: String
    let version: Int
}
```

**Timezone handling**: `returnAt` is always stored in UTC. The `returnAtTimeZone` field records the user's intent -- "tomorrow morning" in Pacific time means 9:00 AM Pacific, which is 17:00 UTC. When the hub evaluates snooze returns, it compares against UTC. When devices display "returns at...", they convert from UTC to the device's local timezone.

#### Recommendation

```swift
struct Recommendation: Codable, Identifiable {
    let id: UUID
    let type: RecommendationType
    let title: String
    let creator: String?                  // Author, director, artist, etc.
    let sourceClassificationId: UUID      // The newsletter it was extracted from
    let sourceNewsletterName: String
    let contextSnippet: String            // The paragraph mentioning it
    let extractedAt: Date
    let confidence: Double
    let status: RecommendationStatus
    let statusUpdatedAt: Date             // For LWW resolution on status
    let duplicateOfId: UUID?              // If consolidated with another recommendation
    let duplicateCount: Int               // "Recommended by N sources"
    let version: Int

    enum RecommendationType: String, Codable {
        case book, movie, tv, music, article, podcast, other
    }

    enum RecommendationStatus: String, Codable {
        case new, saved, done, dismissed
    }
}
```

#### DailyDigest

```swift
struct DailyDigest: Codable, Identifiable {
    let id: UUID
    let generatedAt: Date
    let digestType: DigestType            // morning or evening
    let actionQueueCount: Int
    let snoozedReturningToday: [UUID]     // Classification IDs returning today
    let readingQueueCount: Int
    let borderlineItems: [UUID]           // Uncertain classifications for review
    let notableTransactional: [TransactionalHighlight]
    let sentCount: Int?                   // Evening only
    let archivedCount: Int?               // Evening only
    let multiSnoozeNudges: [UUID]         // Items snoozed 3+ times
    let version: Int

    enum DigestType: String, Codable {
        case morning, evening
    }

    struct TransactionalHighlight: Codable {
        let classificationId: UUID
        let highlightType: String         // "package_arriving", "large_charge", etc.
        let displayText: String
    }
}
```

### Sync Protocol Design

#### Change Feed Approach

Rather than syncing individual records, the server maintains a **change feed** -- an ordered log of all changes with monotonically increasing sequence numbers.

```swift
struct SyncChange: Codable {
    let sequenceNumber: Int64             // Global, monotonically increasing
    let timestamp: Date
    let entityType: String                // "classification", "override", "snooze", etc.
    let entityId: UUID
    let changeType: ChangeType           // created, updated, deleted
    let payload: Data                     // JSON-encoded entity

    enum ChangeType: String, Codable {
        case created, updated, deleted
    }
}
```

Devices track their last-seen sequence number. On reconnect:

```
GET /sync/changes?since=12345
-> Returns all changes with sequenceNumber > 12345
```

This is efficient, simple, and handles offline gaps naturally. The device applies changes in order and updates its cursor.

#### Real-Time Push

Over WebSocket, the server pushes new changes as they occur:

```swift
// Server -> Device
struct SyncPush: Codable {
    let changes: [SyncChange]
}

// Device -> Server
struct SyncAck: Codable {
    let lastSequenceNumber: Int64
}
```

#### Versioning and Conflict Resolution

Each record has a `version` field (integer, incremented on each update). When a device sends an override or snooze change:

1. Device sends the change with the entity's current version
2. Server checks: does the version match the current version?
3. If yes: apply the change, increment version, append to change feed
4. If no: return the current server state. Device merges (for our data, this means: compare timestamps, latest wins)

For our single-user, hub-and-spoke architecture, conflicts are rare. The most likely scenario is two devices sending overrides for the same email at nearly the same time. LWW with timestamps resolves this correctly.

### Database Schema (SQLite)

```sql
CREATE TABLE email_classifications (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    classification TEXT NOT NULL,
    confidence REAL NOT NULL,
    summary TEXT,
    sender_email TEXT NOT NULL,
    sender_name TEXT,
    subject TEXT NOT NULL,
    received_at TEXT NOT NULL,
    processed_at TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_read INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE user_overrides (
    id TEXT PRIMARY KEY,
    classification_id TEXT NOT NULL REFERENCES email_classifications(id),
    previous_classification TEXT NOT NULL,
    new_classification TEXT NOT NULL,
    overridden_at TEXT NOT NULL,
    device_id TEXT NOT NULL,
    is_training_signal INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE snooze_states (
    id TEXT PRIMARY KEY,
    classification_id TEXT NOT NULL REFERENCES email_classifications(id),
    snoozed_at TEXT NOT NULL,
    return_at TEXT NOT NULL,
    return_at_time_zone TEXT NOT NULL,
    snooze_count INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    device_id TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE recommendations (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    creator TEXT,
    source_classification_id TEXT NOT NULL REFERENCES email_classifications(id),
    source_newsletter_name TEXT NOT NULL,
    context_snippet TEXT NOT NULL,
    extracted_at TEXT NOT NULL,
    confidence REAL NOT NULL,
    status TEXT NOT NULL DEFAULT 'new',
    status_updated_at TEXT NOT NULL,
    duplicate_of_id TEXT REFERENCES recommendations(id),
    duplicate_count INTEGER NOT NULL DEFAULT 1,
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE daily_digests (
    id TEXT PRIMARY KEY,
    generated_at TEXT NOT NULL,
    digest_type TEXT NOT NULL,
    payload TEXT NOT NULL,  -- JSON blob for flexibility
    version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE sync_changes (
    sequence_number INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    change_type TEXT NOT NULL,
    payload TEXT NOT NULL
);

CREATE INDEX idx_sync_changes_seq ON sync_changes(sequence_number);
CREATE INDEX idx_classifications_received ON email_classifications(received_at);
CREATE INDEX idx_classifications_classification ON email_classifications(classification);
CREATE INDEX idx_snooze_return ON snooze_states(return_at) WHERE is_active = 1;
CREATE INDEX idx_recommendations_status ON recommendations(status);
```

---

## 7. Existing Solutions

### iCloud Drive (File-Based Sync)

Using `NSUbiquitousKeyValueStore` or iCloud Documents to sync data as files or key-value pairs.

**NSUbiquitousKeyValueStore:**
- Syncs key-value pairs across devices via iCloud
- Limited to 1 MB total, 1024 keys
- Sync latency: 10-20 seconds under good conditions, potentially minutes under load
- Good for: user preferences, small settings
- Not appropriate for: our classification database (too much data, too many records)

**iCloud Documents:**
- Sync files via iCloud Drive
- Could store the entire classification database as a file
- Uses `NSFileCoordinator` for conflict prevention
- Sync timing is system-controlled and opaque
- Two-stage sync process (app container -> system directory -> iCloud)

**Assessment:** iCloud Documents could theoretically work -- store the SQLite database as an iCloud Document and let the system sync it. But this has serious problems:
- SQLite files are not designed for file-level sync. Partial syncs corrupt the database
- No incremental updates -- the entire file syncs on every change
- Conflict resolution at the file level is crude (pick one version)
- No real-time push notifications

**Verdict**: Not appropriate for our use case. The data patterns need record-level sync, not file-level sync.

### Firebase (Realtime Database / Firestore)

Google's cloud database with real-time sync SDKs for iOS.

**Firestore (newer, recommended):**
- Document-based NoSQL database with real-time listeners
- Offline support with local caching
- Automatic conflict resolution (last write wins at the field level)
- Free tier: 1 GB storage, 50K reads / 20K writes / 20K deletes per day
- Paid tier: $0.18 per 100K reads, $0.18 per 100K writes

**Realtime Database (older):**
- JSON tree structure with real-time sync
- Simpler data model, fewer query capabilities
- Lower latency (sub-50ms sync)
- Free tier: 1 GB stored, 10 GB download per month

**Assessment for our case:**
- Firestore's free tier is more than adequate for our data volume
- Real-time listeners are exactly what we need for push updates
- Offline support means devices work when disconnected
- Security rules can enforce our hub-writes-classifications, devices-write-overrides pattern

**However:**
- Introduces Google cloud dependency (counter to the privacy-first philosophy)
- Data transits through Google's servers (email classification metadata, subjects, sender info)
- Vendor lock-in concerns. Pricing can escalate unpredictably if usage patterns change
- Adding a non-Apple dependency to an otherwise pure Apple ecosystem app

**Verdict**: Technically capable but philosophically misaligned. The brief emphasizes privacy-preserving, on-device intelligence. Sending classification metadata (which includes email subjects and sender info) through Google's cloud contradicts that principle. If cross-platform were ever needed, Firestore would be the pragmatic choice.

### Atlas Device Sync (formerly Realm Sync)

**Status as of late 2025: Deprecated and end-of-life.**

MongoDB deprecated Atlas Device Sync, Atlas Edge Server, and the Atlas Device SDKs (formerly Realm) effective September 30, 2025. The client-side Realm database continues as an open-source project but without MongoDB's active support.

**Alternatives that have emerged:**
- **Couchbase Mobile**: Offline-first with peer-to-peer sync capability
- **PowerSync**: SQLite-based sync with Postgres/MongoDB backend
- **ObjectBox**: Embedded database with built-in sync

**PowerSync** is worth a brief note: it syncs a server-side Postgres database to on-device SQLite databases, with a Swift SDK. It is essentially "managed sync infrastructure" -- you run Postgres, PowerSync handles the replication to client SQLite databases. The Swift SDK is relatively new (built on the Kotlin SDK via SKIE interop).

**Verdict**: Realm/Atlas is dead. PowerSync is interesting but adds infrastructure complexity (requires Postgres + PowerSync service). For our single-user, Apple-only case, the simpler approaches (CloudKit or custom server) are more appropriate.

---

## 8. Final Recommendation

### Primary Architecture: Mac Mini Custom Server

```
+--------------------------------------------------+
|  Mac Mini (Always On)                            |
|                                                  |
|  +------------------+  +---------------------+   |
|  | IMAP Poller      |  | AI Classification   |   |
|  | (3 accounts)     |->| Engine (CoreML)     |   |
|  +------------------+  +---------------------+   |
|                               |                  |
|                               v                  |
|                    +---------------------+       |
|                    | SQLite Database     |       |
|                    | (GRDB.swift)        |       |
|                    +---------------------+       |
|                               |                  |
|                               v                  |
|                    +---------------------+       |
|                    | Sync Server         |       |
|                    | (Hummingbird)       |       |
|                    | REST + WebSocket    |       |
|                    +---------------------+       |
|                         |          |             |
+-------------------------|----------|-------------+
                          |          |
                Local WiFi|          |Tailscale (remote)
                          |          |
                    +-----+----+  +--+-------+
                    | iPhone   |  | MacBook  |
                    | iPad     |  | (away)   |
                    +----------+  +----------+
```

### Technology Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Server framework | Hummingbird 2 (Swift) | Lightweight, shared types with clients, modern async/await |
| Database | SQLite via GRDB.swift | Simplest correct choice for single-user metadata |
| Backup | Litestream -> S3-compatible storage | Continuous WAL replication, point-in-time recovery |
| Sync protocol | REST + WebSocket | REST for CRUD, WebSocket for real-time push |
| Remote access | Tailscale | Zero-config VPN, free, encrypted |
| Client storage | SQLite via GRDB.swift | Same stack on client, offline-first |
| Serialization | Codable (JSON) | Native Swift, human-readable, debuggable |

### Implementation Phases

**Phase 1: Local-only Mac Mini server**
- Hummingbird server with REST API for classifications, overrides, snoozes
- SQLite database with GRDB.swift
- macOS client connects to local server
- Prove the data model and sync protocol work

**Phase 2: Multi-device with local network**
- iOS client with the same sync logic
- Bonjour service advertisement for auto-discovery on local network
- Offline queue on clients for when server is unreachable

**Phase 3: Remote access**
- Tailscale integration for out-of-home sync
- WebSocket push for real-time updates
- Litestream backup for disaster recovery

**Phase 4 (optional): CloudKit backup layer**
- If Mac Mini reliability becomes a concern
- Mac Mini writes critical state to CloudKit as a secondary store
- Devices can fall back to CloudKit when Mac Mini is unreachable

### Why Not CloudKit as Primary?

CloudKit would work. For many apps, it would be the right choice. But for this specific project:

1. **The Mac Mini is already the brain.** It has the database. Adding a thin HTTP layer to expose that database is less work than maintaining a separate CloudKit sync layer alongside the local database.

2. **Debugging and iteration speed.** During the critical training period (first two weeks), we will be tuning classifications, adjusting thresholds, and watching how overrides flow back as training signals. Being able to query the SQLite database directly, inspect the change feed, and debug the sync protocol with standard HTTP tools (curl, Proxyman) is vastly more productive than fighting CloudKit Console.

3. **The data model will evolve.** Email classification is module one. Calendar, tasks, and other modules will follow. A custom server gives us the freedom to evolve the API and data model without being constrained by CloudKit's schema deployment process.

4. **Privacy alignment.** The brief states "local AI processing" and "privacy-preserving." Keeping sync on a private Tailscale network rather than routing through iCloud keeps the architecture consistent with that philosophy.

CloudKit remains a good fallback option and could be added later as a backup layer without changing the primary architecture.
