import SwiftUI

/// The compose/reply/forward email view.
/// Presented as a sheet on both macOS and iOS.
public struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: ComposeStore
    let accounts: [Account]
    let apiClient: APIClient?

    @State private var contactsProvider = ContactsProvider()
    @State private var toSuggestions: [ContactSuggestion] = []
    @State private var ccSuggestions: [ContactSuggestion] = []
    @State private var bccSuggestions: [ContactSuggestion] = []

    public init(store: ComposeStore, accounts: [Account], apiClient: APIClient?) {
        self.store = store
        self.accounts = accounts
        self.apiClient = apiClient
    }

    public var body: some View {
        NavigationStack {
            Form {
                // From account picker
                if accounts.count > 1 {
                    Picker("From", selection: $store.accountID) {
                        ForEach(accounts) { account in
                            Text(account.emailAddress)
                                .tag(account.id)
                        }
                    }
                } else if let account = accounts.first {
                    LabeledContent("From") {
                        Text(account.emailAddress)
                            .foregroundStyle(.secondary)
                    }
                }

                // Recipients
                Section {
                    RecipientField(
                        label: "To:",
                        recipients: $store.to,
                        suggestions: toSuggestions,
                        onQueryChanged: { query in
                            Task { toSuggestions = await contactsProvider.search(query: query) }
                        }
                    )

                    if store.showCcBcc {
                        RecipientField(
                            label: "Cc:",
                            recipients: $store.cc,
                            suggestions: ccSuggestions,
                            onQueryChanged: { query in
                                Task { ccSuggestions = await contactsProvider.search(query: query) }
                            }
                        )

                        RecipientField(
                            label: "Bcc:",
                            recipients: $store.bcc,
                            suggestions: bccSuggestions,
                            onQueryChanged: { query in
                                Task { bccSuggestions = await contactsProvider.search(query: query) }
                            }
                        )
                    }
                }

                // Subject
                TextField("Subject", text: $store.subject)

                // Body
                Section {
                    TextEditor(text: $store.body)
                        .frame(minHeight: 200)
                        #if os(macOS)
                        .font(.body)
                        #endif
                }

                // Error
                if let error = store.sendError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitle)
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 400)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        Task {
                            await store.deleteDraft(using: apiClient)
                            dismiss()
                        }
                    }
                    .disabled(store.isSending)
                }

                ToolbarItem(placement: .primaryAction) {
                    if !store.showCcBcc {
                        Button("Cc/Bcc") {
                            store.showCcBcc = true
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await store.send(using: apiClient)
                            if store.didSend { dismiss() }
                        }
                    } label: {
                        if store.isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Send", systemImage: "paperplane.fill")
                        }
                    }
                    .disabled(store.to.isEmpty || store.isSending)
                    #if os(macOS)
                    .keyboardShortcut(.return, modifiers: .command)
                    #endif
                }
            }
            .task {
                _ = await contactsProvider.requestAccess()
            }
        }
    }

    private var navigationTitle: String {
        switch store.mode {
        case .new: "New Email"
        case .reply: "Reply"
        case .replyAll: "Reply All"
        case .forward: "Forward"
        }
    }
}
