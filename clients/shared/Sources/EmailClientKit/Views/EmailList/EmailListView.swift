import SwiftUI

/// A generic, reusable email list used by all queue views.
///
/// Takes a list of emails and renders them with `EmailRowView`,
/// handling selection binding and empty/loading states.
public struct EmailListView: View {
    public let emails: [Email]
    @Binding public var selectedEmailID: String?
    public var snoozeReturnIDs: Set<String> = []

    public init(
        emails: [Email],
        selectedEmailID: Binding<String?>,
        snoozeReturnIDs: Set<String> = []
    ) {
        self.emails = emails
        self._selectedEmailID = selectedEmailID
        self.snoozeReturnIDs = snoozeReturnIDs
    }

    public var body: some View {
        if emails.isEmpty {
            ContentUnavailableView {
                Label("No emails", systemImage: "tray")
            }
        } else {
            List(selection: $selectedEmailID) {
                ForEach(emails) { email in
                    EmailRowView(
                        email: email,
                        isSelected: email.id == selectedEmailID,
                        isSnoozeReturn: snoozeReturnIDs.contains(email.id)
                    )
                    .tag(email.id)
                    .id(email.id)
                }
            }
            .listStyle(.plain)
        }
    }
}
