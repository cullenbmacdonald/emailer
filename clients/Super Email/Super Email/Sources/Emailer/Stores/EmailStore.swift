import Foundation
import Observation
import EmailClientKit

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
