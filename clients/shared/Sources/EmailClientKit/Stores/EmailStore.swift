import Foundation
import Observation

/// Manages email lists for all views and handles WebSocket events.
@Observable
@MainActor
public final class EmailStore {
    /// Emails in the Action Queue view.
    public private(set) var actionQueue: [Email] = []

    /// Emails in the Reading Queue view.
    public private(set) var readingQueue: [Email] = []

    /// Emails in the Filtered view.
    public private(set) var filtered: [Email] = []

    /// Emails in the All Inboxes view.
    public private(set) var allInboxes: [Email] = []

    /// Whether we are performing the initial load for a view.
    public private(set) var isLoading: Bool = false

    /// Cursor for paginating the action queue.
    public private(set) var actionQueueCursor: String?

    /// Whether more action queue pages are available.
    public private(set) var actionQueueHasMore: Bool = false

    /// The currently loaded email detail.
    public private(set) var selectedDetail: EmailDetail?

    /// Number of action queue items (for sidebar badge).
    public var actionQueueCount: Int { actionQueue.count }

    /// Number of filtered items with confidence < 0.80 (for sidebar badge).
    public var filteredBorderlineCount: Int {
        filtered.filter { $0.classification.confidence < 0.80 }.count
    }

    public init() {}

    /// Handle a WebSocket event that affects emails.
    public func handleEvent(_ event: WebSocketEvent) {
        switch event.payload {
        case let .emailNew(payload):
            insertEmail(payload.email)
        case let .emailUpdated(payload):
            updateEmail(payload.email)
        case let .emailDeleted(payload):
            removeEmail(id: payload.emailId)
        case let .classificationChanged(payload):
            if let email = payload.email {
                removeEmail(id: email.id)
                insertEmail(email)
            }
        case let .snoozeCreated(payload):
            removeEmail(id: payload.emailId)
        case let .snoozeReturned(payload):
            insertEmail(payload.email)
        case let .snoozeCancelled(payload):
            insertEmail(payload.email)
        default:
            break
        }
    }

    /// Replace all emails for a specific view (used for initial fetch).
    public func setEmails(_ emails: [Email], for view: EmailView) {
        switch view {
        case .actionQueue:
            actionQueue = emails
        case .readingQueue:
            readingQueue = emails
        case .filtered:
            filtered = emails
        case .allInboxes:
            allInboxes = emails
        }
    }

    // MARK: - Loading

    /// Set loading state (used by coordinator or view to track first load).
    public func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Update pagination state for the action queue.
    public func setActionQueuePagination(cursor: String?, hasMore: Bool) {
        actionQueueCursor = cursor
        actionQueueHasMore = hasMore
    }

    /// Append a page of emails to the action queue (for pagination).
    public func appendActionQueueEmails(_ emails: [Email]) {
        let existingIDs = Set(actionQueue.map(\.id))
        for email in emails where !existingIDs.contains(email.id) {
            actionQueue.append(email)
        }
    }

    /// Load the detail for a specific email. Clears the current detail first.
    /// Automatically marks the email as read upon successful load.
    public func loadDetail(for emailID: String, using client: APIClient?) async {
        selectedDetail = nil
        guard let client else { return }
        do {
            let detail = try await client.fetchEmailDetail(id: emailID)
            selectedDetail = detail

            // Mark as read if unread
            if !detail.email.isRead {
                _ = try? await client.updateEmail(id: emailID, isRead: true)
            }
        } catch {
            // Detail load failed -- leave selectedDetail as nil
        }
    }

    /// Clear the selected detail.
    public func clearDetail() {
        selectedDetail = nil
    }

    // MARK: - Optimistic Mutations

    /// Remove an email from the action queue (for optimistic archive/trash).
    /// Returns the removed email so it can be restored on undo.
    @discardableResult
    public func removeFromActionQueue(id: String) -> Email? {
        guard let index = actionQueue.firstIndex(where: { $0.id == id }) else { return nil }
        let email = actionQueue.remove(at: index)
        allInboxes.removeAll { $0.id == id }
        return email
    }

    /// Restore a previously removed email to the action queue (for undo).
    public func restoreToActionQueue(_ email: Email) {
        upsert(email, into: &actionQueue)
        upsert(email, into: &allInboxes)
    }

    /// Remove an email from the filtered list (for optimistic rescue/confirm/delete).
    /// Returns the removed email so it can be restored on undo.
    @discardableResult
    public func removeFromFiltered(id: String) -> Email? {
        guard let index = filtered.firstIndex(where: { $0.id == id }) else { return nil }
        let email = filtered.remove(at: index)
        allInboxes.removeAll { $0.id == id }
        return email
    }

    /// Restore a previously removed email to the filtered list (for undo).
    public func restoreToFiltered(_ email: Email) {
        upsert(email, into: &filtered)
        upsert(email, into: &allInboxes)
    }

    /// Update the read state of an email across all lists.
    public func updateReadState(id: String, isRead: Bool) {
        updateField(id: id, in: &actionQueue) { $0.withReadState(isRead) }
        updateField(id: id, in: &readingQueue) { $0.withReadState(isRead) }
        updateField(id: id, in: &filtered) { $0.withReadState(isRead) }
        updateField(id: id, in: &allInboxes) { $0.withReadState(isRead) }
    }

    private func updateField(id: String, in list: inout [Email], transform: (Email) -> Email) {
        if let index = list.firstIndex(where: { $0.id == id }) {
            list[index] = transform(list[index])
        }
    }

    // MARK: - Private

    private func insertEmail(_ email: Email) {
        let classification = email.classification.classification
        switch classification {
        case .actionRequired:
            upsert(email, into: &actionQueue)
        case .newsletter:
            upsert(email, into: &readingQueue)
        case .filtered, .transactional:
            upsert(email, into: &filtered)
        }
        upsert(email, into: &allInboxes)
    }

    private func updateEmail(_ email: Email) {
        upsert(email, into: &actionQueue)
        upsert(email, into: &readingQueue)
        upsert(email, into: &filtered)
        upsert(email, into: &allInboxes)
    }

    private func removeEmail(id: String) {
        actionQueue.removeAll { $0.id == id }
        readingQueue.removeAll { $0.id == id }
        filtered.removeAll { $0.id == id }
        allInboxes.removeAll { $0.id == id }
    }

    private func upsert(_ email: Email, into list: inout [Email]) {
        if let index = list.firstIndex(where: { $0.id == email.id }) {
            list[index] = email
        } else {
            list.insert(email, at: 0)
        }
    }
}
