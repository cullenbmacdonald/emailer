import SwiftUI

/// The account filter options.
public enum AccountFilter: Hashable, Sendable, CaseIterable, Identifiable {
    case all
    case work
    case personal
    /// A specific account by ID and name (not included in CaseIterable).
    case account(id: String, name: String)

    public var id: String {
        switch self {
        case .all: "all"
        case .work: "work"
        case .personal: "personal"
        case .account(let id, _): "account-\(id)"
        }
    }

    public var label: String {
        switch self {
        case .all: "All"
        case .work: "Work"
        case .personal: "Personal"
        case .account(_, let name): name
        }
    }

    public var dotColor: Color? {
        switch self {
        case .all: nil
        case .work: .accountWork
        case .personal: .accountPersonal1
        case .account: nil
        }
    }

    /// CaseIterable conformance for the basic cases only.
    public static var allCases: [AccountFilter] {
        [.all, .work, .personal]
    }
}

/// A menu item representing an email account for the filter menu.
public struct AccountMenuItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: Color

    public init(id: String, name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }

    /// Default placeholder accounts until real data is available.
    public static let defaults: [AccountMenuItem] = [
        AccountMenuItem(id: "work", name: "Work", color: .accountWork),
        AccountMenuItem(id: "personal1", name: "Personal", color: .accountPersonal1),
        AccountMenuItem(id: "personal2", name: "Personal 2", color: .accountPersonal2),
    ]
}

#if os(macOS)
/// Segmented control for filtering by account (macOS).
public struct AccountFilterControl: View {
    @Binding public var selection: AccountFilter

    public init(selection: Binding<AccountFilter>) {
        self._selection = selection
    }

    public var body: some View {
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
#endif

#if os(iOS)
/// Toolbar menu button for filtering by email account (iOS).
public struct AccountFilterMenu: View {
    @Binding public var accountFilter: AccountFilter

    /// The list of accounts to show in the filter menu.
    public let accounts: [AccountMenuItem]

    public init(
        accountFilter: Binding<AccountFilter>,
        accounts: [AccountMenuItem] = AccountMenuItem.defaults
    ) {
        self._accountFilter = accountFilter
        self.accounts = accounts
    }

    public var body: some View {
        Menu {
            Button {
                accountFilter = .all
            } label: {
                if case .all = accountFilter {
                    Label("All Accounts", systemImage: "checkmark")
                } else {
                    Text("All Accounts")
                }
            }

            Divider()

            ForEach(accounts) { account in
                Button {
                    accountFilter = .account(
                        id: account.id,
                        name: account.name
                    )
                } label: {
                    HStack {
                        Circle()
                            .fill(account.color)
                            .frame(width: 8, height: 8)
                        Text(account.name)
                        if case .account(let id, _) = accountFilter,
                           id == account.id {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .accessibilityLabel("Filter by account")
        }
    }
}
#endif
