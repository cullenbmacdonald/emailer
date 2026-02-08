import SwiftUI

/// A filtered email list row with confidence score, days remaining, and borderline indicator.
///
/// Layout (72pt height):
/// ```
/// [dot] [!!] noreply@promo.com                  2:15 PM
///            50% off everything this weekend
///            Don't miss our biggest sale of...
///            Confidence: 95%                     [14d left]
/// ```
public struct FilteredRowView: View {
    public let email: Email
    public let isSelected: Bool
    public let isBorderline: Bool

    #if os(macOS)
    @State private var isHovering = false
    #endif

    public init(email: Email, isSelected: Bool, isBorderline: Bool = false) {
        self.email = email
        self.isSelected = isSelected
        self.isBorderline = isBorderline
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            leadingContent
            mainContent
        }
        .padding(.horizontal, ListRowMetrics.horizontalPadding)
        .padding(.vertical, ListRowMetrics.verticalPadding)
        #if os(iOS)
        .frame(minHeight: 80)
        #else
        .frame(minHeight: 72)
        #endif
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

    // MARK: - Leading Content

    @ViewBuilder
    private var leadingContent: some View {
        VStack(spacing: Spacing.xs) {
            AccountDot(
                color: accountColor,
                accountName: email.accountName ?? "Unknown"
            )

            if isBorderline {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.snooze)
                    .accessibilityLabel("Borderline classification, may not be spam")
            }
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            firstLine
            secondLine
            thirdLine
            fourthLine
        }
    }

    /// Sender email (full) + timestamp on the first line.
    private var firstLine: some View {
        HStack {
            Text(email.from.email)
                .font(email.isRead ? .subheadline : .headline)
                .foregroundStyle(email.isRead ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if email.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Has attachments")
            }

            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Subject line on the second line.
    private var secondLine: some View {
        Text(email.subject)
            .font(email.isRead ? .subheadline : .headline)
            .fontWeight(email.isRead ? .regular : .semibold)
            .foregroundStyle(email.isRead ? .secondary : .primary)
            .lineLimit(1)
    }

    /// Snippet on the third line.
    private var thirdLine: some View {
        Text(email.snippet)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    /// Confidence score + days remaining on the fourth line.
    private var fourthLine: some View {
        HStack {
            Text(confidenceText)
                .font(.caption)
                .foregroundStyle(confidenceColor)

            Spacer()

            if let days = email.daysUntilExpiry {
                Text("\(days)d left")
                    .font(.caption2)
                    .foregroundStyle(days < 2 ? Color.destructive : Color.gray)
            }
        }
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

    private var confidenceText: String {
        let pct = Int(email.classification.confidence * 100)
        return "Confidence: \(pct)%"
    }

    private var confidenceColor: Color {
        let confidence = email.classification.confidence
        if confidence < 0.70 {
            return .destructive
        } else if confidence < 0.80 {
            return .snooze
        } else if confidence < 0.90 {
            return .filteredColor
        } else {
            return .success
        }
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

        parts.append("Filtered email from \(email.from.email)")
        parts.append(email.subject)

        let pct = Int(email.classification.confidence * 100)
        parts.append("confidence \(pct) percent")

        if let days = email.daysUntilExpiry {
            parts.append("\(days) days until auto-delete")
        }

        if isBorderline {
            parts.append("borderline classification, may not be spam")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview Data

public extension Email {
    static var previewFiltered: Email {
        Email(
            id: "filtered-1",
            accountId: "acc-personal",
            from: Contact(name: nil, email: "noreply@promo.com"),
            to: [Contact(name: "You", email: "you@personal.com")],
            subject: "50% off everything this weekend",
            snippet: "Don't miss our biggest sale of the year",
            receivedAt: Date().addingTimeInterval(-86400),
            classification: Classification(
                classification: .filtered,
                confidence: 0.95,
                classifiedBy: .features,
                reason: "Marketing language detected, promotional content"
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            accountColor: "#22C55E",
            accountName: "Personal",
            daysUntilExpiry: 13
        )
    }

    static var previewBorderline: Email {
        Email(
            id: "filtered-2",
            accountId: "acc-personal",
            from: Contact(name: nil, email: "support@bank.com"),
            to: [Contact(name: "You", email: "you@personal.com")],
            subject: "Your statement is ready",
            snippet: "Please review your January statement and contact us if you have questions",
            receivedAt: Date().addingTimeInterval(-7200),
            classification: Classification(
                classification: .filtered,
                confidence: 0.68,
                classifiedBy: .llm,
                reason: "Marketing language detected, but sender is in your contacts"
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            accountColor: "#22C55E",
            accountName: "Personal",
            daysUntilExpiry: 14
        )
    }
}

#Preview("FilteredRowView - Standard") {
    FilteredRowView(email: .previewFiltered, isSelected: false)
        .frame(width: 340)
}

#Preview("FilteredRowView - Borderline") {
    FilteredRowView(email: .previewBorderline, isSelected: false, isBorderline: true)
        .frame(width: 340)
}

#Preview("FilteredRowView - Selected") {
    FilteredRowView(email: .previewBorderline, isSelected: true, isBorderline: true)
        .frame(width: 340)
}
