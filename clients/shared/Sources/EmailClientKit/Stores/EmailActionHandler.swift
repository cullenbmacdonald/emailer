import Foundation
import Observation

/// Handles email actions (archive, trash, toggle read, snooze) with optimistic
/// UI updates and undo support. Used by both macOS and iOS action views.
@Observable
@MainActor
public final class EmailActionHandler {
    /// The currently displayed undo toast info, if any.
    public private(set) var undoToast: UndoToastInfo?

    /// Whether the snooze picker is currently presented.
    public var showSnoozePicker: Bool = false

    /// The email ID being snoozed (set before presenting the snooze picker).
    public var snoozeTargetEmailID: String?

    public init() {}

    // MARK: - Actions

    /// Archive an email optimistically.
    public func archive(
        emailID: String,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        // Optimistic removal
        let removedEmail = emailStore.removeFromActionQueue(id: emailID)

        undoToast = UndoToastInfo(
            message: "Email archived",
            undoAction: { [weak emailStore] in
                if let email = removedEmail {
                    emailStore?.restoreToActionQueue(email)
                }
            }
        )

        Task {
            do {
                _ = try await apiClient?.updateEmail(id: emailID, isArchived: true)
            } catch {
                // Restore on failure
                if let email = removedEmail {
                    emailStore.restoreToActionQueue(email)
                }
            }
        }
    }

    /// Move an email to trash optimistically.
    public func trash(
        emailID: String,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        let removedEmail = emailStore.removeFromActionQueue(id: emailID)

        undoToast = UndoToastInfo(
            message: "Email deleted",
            undoAction: { [weak emailStore] in
                if let email = removedEmail {
                    emailStore?.restoreToActionQueue(email)
                }
            }
        )

        Task {
            do {
                try await apiClient?.deleteEmail(id: emailID)
            } catch {
                if let email = removedEmail {
                    emailStore.restoreToActionQueue(email)
                }
            }
        }
    }

    /// Toggle the read/unread state of an email.
    public func toggleRead(
        emailID: String,
        isCurrentlyRead: Bool,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        let newReadState = !isCurrentlyRead

        // Optimistic update
        emailStore.updateReadState(id: emailID, isRead: newReadState)

        Task {
            do {
                _ = try await apiClient?.updateEmail(id: emailID, isRead: newReadState)
            } catch {
                // Revert on failure
                emailStore.updateReadState(id: emailID, isRead: isCurrentlyRead)
            }
        }
    }

    /// Begin a snooze flow: set the target email and present the picker.
    public func beginSnooze(emailID: String) {
        snoozeTargetEmailID = emailID
        showSnoozePicker = true
    }

    /// Dismiss the undo toast.
    public func dismissUndoToast() {
        undoToast = nil
    }
}

/// Information for displaying an undo toast.
public struct UndoToastInfo: Sendable {
    public let message: String
    public let undoAction: @Sendable @MainActor () -> Void

    public init(message: String, undoAction: @escaping @Sendable @MainActor () -> Void) {
        self.message = message
        self.undoAction = undoAction
    }
}
