import SwiftUI

/// A newsletter-specific list row for the Reading Queue.
///
/// Differences from standard EmailRowView:
/// - Newsletter source name as primary text (`.headline` weight)
/// - No bold/unread distinction -- read/unread is conveyed via opacity (0.7 for read)
/// - No snooze badges
/// - No snooze return indicator
/// Layout (64pt macOS, 72pt iOS):
/// ```
/// [dot]  Stratechery                              Today
///        The End of the Beginning
///        This week I want to revisit a theme...
/// ```
public struct ReadingQueueRowView: View {
    public let email: Email
    public let isSelected: Bool

    #if os(macOS)
    @State private var isHovering = false
    #endif

    public init(email: Email, isSelected: Bool) {
        self.email = email
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            AccountDot(
                color: accountColor,
                accountName: email.accountName ?? "Unknown"
            )
            .padding(.top, Spacing.xs)

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Source name + timestamp
                HStack {
                    Text(senderDisplayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(relativeTimestamp)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Line 2: Subject
                Text(email.subject)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Line 3: Snippet
                Text(email.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, ListRowMetrics.horizontalPadding)
        .padding(.vertical, ListRowMetrics.verticalPadding)
        .frame(minHeight: ListRowMetrics.rowHeight)
        .opacity(email.isRead ? 0.7 : 1.0)
        .background(rowBackground)
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        #if os(macOS)
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovering {
            Color(nsColor: .quaternarySystemFill)
        } else {
            Color.clear
        }
        #else
        Color.clear
        #endif
    }

    // MARK: - Helpers

    private var senderDisplayName: String {
        email.from.name ?? email.from.email
    }

    private var accountColor: Color {
        guard let hex = email.accountColor else { return .gray }
        return Color(hexString: hex)
    }

    private var relativeTimestamp: String {
        let now = Date.now
        let interval = now.timeIntervalSince(email.receivedAt)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400, Calendar.current.isDateInToday(email.receivedAt) {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if Calendar.current.isDateInYesterday(email.receivedAt) {
            return "Yesterday"
        } else {
            return email.receivedAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        parts.append("Newsletter from \(senderDisplayName)")
        parts.append(email.subject)
        parts.append(relativeTimestamp)
        if !email.isRead {
            parts.append("unread")
        }
        return parts.joined(separator: ", ")
    }
}
