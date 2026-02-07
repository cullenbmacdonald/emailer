import SwiftUI

/// The account filter options.
public enum AccountFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case work
    case personal

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .all: "All"
        case .work: "Work"
        case .personal: "Personal"
        }
    }

    public var dotColor: Color? {
        switch self {
        case .all: nil
        case .work: .accountWork
        case .personal: .accountPersonal1
        }
    }
}

/// Segmented control for filtering by account.
struct AccountFilterControl: View {
    @Binding var selection: AccountFilter

    var body: some View {
        Picker("Account filter", selection: $selection) {
            ForEach(AccountFilter.allCases) { filter in
                HStack(spacing: Spacing.xs) {
                    if let dotColor = filter.dotColor {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)
                    }
                    Text(filter.label)
                }
                .tag(filter)
                .accessibilityLabel(filter.label)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Account filter")
    }
}

#Preview("AccountFilterControl") {
    struct PreviewWrapper: View {
        @State var filter: AccountFilter = .all
        var body: some View {
            AccountFilterControl(selection: $filter)
                .frame(width: 220)
                .padding()
        }
    }
    return PreviewWrapper()
}
