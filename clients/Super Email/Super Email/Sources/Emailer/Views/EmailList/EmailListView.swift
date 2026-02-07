import SwiftUI
import EmailClientKit

/// A generic, reusable email list used by all queue views.
///
/// Takes a list of emails and renders them with `EmailRowView`,
/// handling selection binding and empty/loading states.
struct EmailListView: View {
    let emails: [Email]
    @Binding var selectedEmailID: String?
    var snoozeReturnIDs: Set<String> = []

    var body: some View {
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
