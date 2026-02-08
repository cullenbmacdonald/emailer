import SwiftUI

/// Destination for rescuing an email from the Filtered view.
public enum RescueDestination: String, CaseIterable, Sendable {
    case actionQueue
    case readingQueue
    case allInboxes

    public var label: String {
        switch self {
        case .actionQueue: "Action Queue"
        case .readingQueue: "Reading Queue"
        case .allInboxes: "All Inboxes (Transactional)"
        }
    }

    public var icon: String {
        switch self {
        case .actionQueue: "tray.and.arrow.down"
        case .readingQueue: "book"
        case .allInboxes: "tray"
        }
    }

    public var shortcutKey: String {
        switch self {
        case .actionQueue: "1"
        case .readingQueue: "2"
        case .allInboxes: "3"
        }
    }

    /// The classification to reclassify the email to.
    public var targetClassification: ClassificationType {
        switch self {
        case .actionQueue: .actionRequired
        case .readingQueue: .newsletter
        case .allInboxes: .transactional
        }
    }
}

/// A popover (macOS) or action sheet (iOS) for choosing where to move a rescued email.
public struct RescuePicker: View {
    public let onSelect: (RescueDestination) -> Void

    public init(onSelect: @escaping (RescueDestination) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Move to:")
                .font(.headline)
                .padding(.bottom, Spacing.xs)

            ForEach(RescueDestination.allCases, id: \.self) { destination in
                Button {
                    onSelect(destination)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: destination.icon)
                            .frame(width: 20)

                        Text(destination.label)

                        Spacer()

                        #if os(macOS)
                        Text(destination.shortcutKey)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                        #endif
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.lg)
        .frame(minWidth: 260)
    }
}

#Preview("RescuePicker") {
    RescuePicker { destination in
        print("Selected: \(destination)")
    }
}
