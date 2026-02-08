import Foundation
import Observation

/// The mode in which the compose view was opened.
public enum ComposeMode: Sendable {
    case new
    case reply(EmailDetail)
    case replyAll(EmailDetail)
    case forward(EmailDetail)
}

/// Manages compose/reply/forward state and sends via APIClient.
@Observable
@MainActor
public final class ComposeStore: Identifiable {
    public let id = UUID()
    // MARK: - Fields

    public var to: [String] = []
    public var cc: [String] = []
    public var bcc: [String] = []
    public var subject: String = ""
    public var body: String = ""
    public var accountID: String = ""

    /// The message ID we are replying to, if any.
    public var inReplyTo: String?

    /// The email ID we are forwarding, if any.
    public var forwardOf: String?

    /// The compose mode that was used to initialize this store.
    public let mode: ComposeMode

    /// Whether a send is in progress.
    public var isSending: Bool = false

    /// Error message from last send attempt.
    public var sendError: String?

    /// Whether the send completed successfully.
    public var didSend: Bool = false

    /// The draft ID if this compose has been saved as a draft.
    public var draftID: String?

    /// Whether CC/BCC fields are visible.
    public var showCcBcc: Bool = false

    // MARK: - Init

    public init(mode: ComposeMode, selfEmail: String? = nil, defaultAccountID: String? = nil) {
        self.mode = mode
        self.accountID = defaultAccountID ?? ""

        switch mode {
        case .new:
            break

        case .reply(let detail):
            to = [detail.email.from.email]
            subject = Self.prefixSubject("Re: ", original: detail.email.subject)
            body = Self.quotedReplyBody(detail: detail)
            inReplyTo = detail.email.messageId
            accountID = detail.email.accountId

        case .replyAll(let detail):
            to = [detail.email.from.email]
            // Add original To and CC, excluding self
            let selfAddr = selfEmail?.lowercased() ?? ""
            let originalTo = detail.email.to.map(\.email)
                .filter { $0.lowercased() != selfAddr && $0.lowercased() != detail.email.from.email.lowercased() }
            let originalCc = (detail.email.cc ?? []).map(\.email)
                .filter { $0.lowercased() != selfAddr && $0.lowercased() != detail.email.from.email.lowercased() }
            cc = originalTo + originalCc
            if !cc.isEmpty { showCcBcc = true }
            subject = Self.prefixSubject("Re: ", original: detail.email.subject)
            body = Self.quotedReplyBody(detail: detail)
            inReplyTo = detail.email.messageId
            accountID = detail.email.accountId

        case .forward(let detail):
            subject = Self.prefixSubject("Fwd: ", original: detail.email.subject)
            body = Self.forwardedBody(detail: detail)
            forwardOf = detail.id
            accountID = detail.email.accountId
        }
    }

    // MARK: - Actions

    /// Send the composed email.
    public func send(using client: APIClient?) async {
        guard let client else {
            sendError = "Not connected to server"
            return
        }
        guard !to.isEmpty else {
            sendError = "At least one recipient is required"
            return
        }
        guard !accountID.isEmpty else {
            sendError = "No account selected"
            return
        }

        isSending = true
        sendError = nil

        let request = ComposeRequest(
            accountId: accountID,
            to: to,
            cc: cc.isEmpty ? nil : cc,
            bcc: bcc.isEmpty ? nil : bcc,
            subject: subject,
            body: body,
            inReplyTo: inReplyTo,
            forwardOf: forwardOf
        )

        do {
            _ = try await client.sendEmail(request)
            didSend = true
            // If we had a draft, delete it
            if let draftID {
                try? await client.deleteDraft(id: draftID)
                self.draftID = nil
            }
        } catch {
            sendError = error.localizedDescription
        }

        isSending = false
    }

    /// Save the current state as a draft.
    public func saveDraft(using client: APIClient?) async {
        guard let client, !accountID.isEmpty else { return }

        let request = ComposeRequest(
            accountId: accountID,
            to: to,
            cc: cc.isEmpty ? nil : cc,
            bcc: bcc.isEmpty ? nil : bcc,
            subject: subject,
            body: body,
            inReplyTo: inReplyTo,
            forwardOf: forwardOf
        )

        do {
            if let draftID {
                _ = try await client.updateDraft(id: draftID, request)
            } else {
                let draft = try await client.createDraft(request)
                draftID = draft.id
            }
        } catch {
            // Draft save failed silently
        }
    }

    /// Delete the current draft if one exists.
    public func deleteDraft(using client: APIClient?) async {
        guard let client, let draftID else { return }
        try? await client.deleteDraft(id: draftID)
        self.draftID = nil
    }

    // MARK: - Helpers

    /// Add "Re: " or "Fwd: " prefix, avoiding duplication.
    static func prefixSubject(_ prefix: String, original: String) -> String {
        let trimmed = original.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix(prefix.lowercased()) {
            return trimmed
        }
        return prefix + trimmed
    }

    /// Build quoted reply body from email detail.
    static func quotedReplyBody(detail: EmailDetail) -> String {
        let date = detail.email.receivedAt.formatted(date: .abbreviated, time: .shortened)
        let from = detail.email.from.name ?? detail.email.from.email
        let text = detail.textBody ?? detail.htmlBody.strippingHTMLTags()
        let quoted = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
        return "\n\nOn \(date), \(from) wrote:\n\(quoted)"
    }

    /// Build forwarded message body from email detail.
    static func forwardedBody(detail: EmailDetail) -> String {
        let date = detail.email.receivedAt.formatted(date: .abbreviated, time: .shortened)
        let from = detail.email.from.name.map { "\($0) <\(detail.email.from.email)>" } ?? detail.email.from.email
        let toList = detail.email.to.map(\.email).joined(separator: ", ")
        let text = detail.textBody ?? detail.htmlBody.strippingHTMLTags()
        return """
        \n\n---------- Forwarded message ----------
        From: \(from)
        Date: \(date)
        Subject: \(detail.email.subject)
        To: \(toList)

        \(text)
        """
    }
}

// MARK: - String HTML stripping

extension String {
    /// Naive HTML tag stripping for plain text conversion.
    func strippingHTMLTags() -> String {
        self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
