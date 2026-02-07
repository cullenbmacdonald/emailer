import SwiftUI

/// Displays the email header: From, To, CC, Subject, Date, Account info, snooze badge.
public struct EmailHeaderView: View {
    public let detail: EmailDetail

    public init(detail: EmailDetail) {
        self.detail = detail
    }

    private var email: Email { detail.email }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Subject
            Text(email.subject)
                .font(.title2)
                .fontWeight(.semibold)
                .textSelection(.enabled)

            // From line
            HStack(spacing: Spacing.xs) {
                Text("From:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(contactDisplay(email.from))
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            // To line
            HStack(alignment: .top, spacing: Spacing.xs) {
                Text("To:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(email.to.map { contactDisplay($0) }.joined(separator: ", "))
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            // CC line (if present)
            if let ccList = email.cc, !ccList.isEmpty {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("CC:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(ccList.map { contactDisplay($0) }.joined(separator: ", "))
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }

            // Date + Account row
            HStack(spacing: Spacing.sm) {
                Text(email.receivedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(email.receivedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Account indicator
                if let accountName = email.accountName {
                    HStack(spacing: Spacing.xs) {
                        AccountDot(
                            color: accountColor,
                            accountName: accountName
                        )
                        Text(accountName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Snooze badge
                if let snooze = email.snooze {
                    SnoozeCountBadge(snoozeCount: snooze.snoozeCount)
                }
            }

            // Attachment list
            if !detail.attachments.isEmpty {
                Divider()
                AttachmentListView(attachments: detail.attachments)
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Helpers

    private func contactDisplay(_ contact: Contact) -> String {
        if let name = contact.name, !name.isEmpty {
            return "\(name) <\(contact.email)>"
        }
        return contact.email
    }

    private var accountColor: Color {
        if let colorHex = email.accountColor {
            return Color(hexString: colorHex)
        }
        return .accountWork
    }
}

// MARK: - Attachment List

/// Displays a horizontal list of attachments below the email header.
public struct AttachmentListView: View {
    public let attachments: [Attachment]

    public init(attachments: [Attachment]) {
        self.attachments = attachments
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Attachments (\(attachments.count))", systemImage: "paperclip")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: Spacing.sm) {
                ForEach(attachments) { attachment in
                    attachmentChip(attachment)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentChip(_ attachment: Attachment) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: iconForMimeType(attachment.mimeType))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(attachment.filename)
                .font(.caption)
                .lineLimit(1)
            Text(formatSize(attachment.size))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.quaternary, in: .capsule)
    }

    private func iconForMimeType(_ mimeType: String) -> String {
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType.hasPrefix("video/") { return "film" }
        if mimeType.hasPrefix("audio/") { return "waveform" }
        if mimeType.contains("pdf") { return "doc.richtext" }
        if mimeType.contains("zip") || mimeType.contains("compressed") { return "doc.zipper" }
        return "doc"
    }

    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Simple Flow Layout

/// A simple horizontal flow layout that wraps items.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> FlowResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return FlowResult(
            positions: positions,
            size: CGSize(width: maxWidth, height: currentY + lineHeight)
        )
    }
}

private struct FlowResult {
    let positions: [CGPoint]
    let size: CGSize
}
