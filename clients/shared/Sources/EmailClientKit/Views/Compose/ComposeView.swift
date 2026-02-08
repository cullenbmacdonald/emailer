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
            #if os(macOS)
            macOSBody
            #else
            iOSBody
            #endif
        }
    }

    // MARK: - macOS

    #if os(macOS)
    private var macOSBody: some View {
        VStack(spacing: 0) {
            // Header fields
            VStack(spacing: 8) {
                // From
                if accounts.count > 1 {
                    fieldRow("From") {
                        Picker("", selection: $store.accountID) {
                            ForEach(accounts) { account in
                                Text(account.emailAddress).tag(account.id)
                            }
                        }
                        .labelsHidden()
                    }
                } else if let account = accounts.first {
                    fieldRow("From") {
                        Text(account.emailAddress)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // To
                fieldRow("To") {
                    RecipientField(
                        recipients: $store.to,
                        suggestions: toSuggestions,
                        onQueryChanged: { query in
                            Task { toSuggestions = await contactsProvider.search(query: query) }
                        }
                    )
                }

                if store.showCcBcc {
                    Divider()
                    fieldRow("Cc") {
                        RecipientField(
                            recipients: $store.cc,
                            suggestions: ccSuggestions,
                            onQueryChanged: { query in
                                Task { ccSuggestions = await contactsProvider.search(query: query) }
                            }
                        )
                    }
                    Divider()
                    fieldRow("Bcc") {
                        RecipientField(
                            recipients: $store.bcc,
                            suggestions: bccSuggestions,
                            onQueryChanged: { query in
                                Task { bccSuggestions = await contactsProvider.search(query: query) }
                            }
                        )
                    }
                }

                Divider()

                // Subject
                fieldRow("Subject") {
                    TextField("", text: $store.subject)
                        .textFieldStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Body
            TextEditor(text: $store.body)
                .font(.body)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Error
            if let error = store.sendError {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 480, idealHeight: 560)
        .navigationTitle(navigationTitle)
        .toolbar { composeToolbar }
        .task { _ = await contactsProvider.requestAccess() }
    }

    @ViewBuilder
    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            content()
        }
    }
    #endif

    // MARK: - iOS

    #if os(iOS)
    private var iOSBody: some View {
        Form {
            if accounts.count > 1 {
                Picker("From", selection: $store.accountID) {
                    ForEach(accounts) { account in
                        Text(account.emailAddress).tag(account.id)
                    }
                }
            } else if let account = accounts.first {
                LabeledContent("From") {
                    Text(account.emailAddress)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                RecipientField(
                    recipients: $store.to,
                    suggestions: toSuggestions,
                    onQueryChanged: { query in
                        Task { toSuggestions = await contactsProvider.search(query: query) }
                    }
                )

                if store.showCcBcc {
                    RecipientField(
                        recipients: $store.cc,
                        suggestions: ccSuggestions,
                        onQueryChanged: { query in
                            Task { ccSuggestions = await contactsProvider.search(query: query) }
                        }
                    )
                    RecipientField(
                        recipients: $store.bcc,
                        suggestions: bccSuggestions,
                        onQueryChanged: { query in
                            Task { bccSuggestions = await contactsProvider.search(query: query) }
                        }
                    )
                }
            }

            TextField("Subject", text: $store.subject)

            Section {
                TextEditor(text: $store.body)
                    .frame(minHeight: 200)
            }

            if let error = store.sendError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(navigationTitle)
        .toolbar { composeToolbar }
        .task { _ = await contactsProvider.requestAccess() }
    }
    #endif

    // MARK: - Shared

    @ToolbarContentBuilder
    private var composeToolbar: some ToolbarContent {
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

    private var navigationTitle: String {
        switch store.mode {
        case .new: "New Email"
        case .reply: "Reply"
        case .replyAll: "Reply All"
        case .forward: "Forward"
        }
    }
}
