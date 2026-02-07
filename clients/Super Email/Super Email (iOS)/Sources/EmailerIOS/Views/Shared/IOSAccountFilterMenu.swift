import SwiftUI

/// Toolbar menu button for filtering by email account.
/// Displays `line.3.horizontal.decrease.circle` icon.
/// Menu items: "All Accounts", divider, each account with colored dot + name.
public struct IOSAccountFilterMenu: View {
    @Environment(IOSAppState.self) private var appState

    /// The list of accounts to show in the filter menu.
    /// Hardcoded for now — will be populated from server in later phases.
    let accounts: [AccountMenuItem]

    public init(accounts: [AccountMenuItem] = AccountMenuItem.defaults) {
        self.accounts = accounts
    }

    public var body: some View {
        Menu {
            Button {
                appState.accountFilter = .all
            } label: {
                if case .all = appState.accountFilter {
                    Label("All Accounts", systemImage: "checkmark")
                } else {
                    Text("All Accounts")
                }
            }

            Divider()

            ForEach(accounts) { account in
                Button {
                    appState.accountFilter = .account(
                        id: account.id,
                        name: account.name
                    )
                } label: {
                    HStack {
                        Circle()
                            .fill(account.color)
                            .frame(width: 8, height: 8)
                        Text(account.name)
                        if case .account(let id, _) = appState.accountFilter,
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
        AccountMenuItem(id: "work", name: "Work", color: .accountWorkFallback),
        AccountMenuItem(
            id: "personal1",
            name: "Personal",
            color: .accountPersonal1Fallback
        ),
        AccountMenuItem(
            id: "personal2",
            name: "Personal 2",
            color: .accountPersonal2Fallback
        )
    ]
}

#Preview("Account Filter Menu") {
    NavigationStack {
        Text("Content")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    IOSAccountFilterMenu()
                }
            }
            .navigationTitle("Action Queue")
    }
    .environment(IOSAppState())
}
