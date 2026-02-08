import SwiftUI

/// A text field that shows email recipients as token chips with autocomplete suggestions.
public struct RecipientField: View {
    let label: String
    @Binding var recipients: [String]
    let suggestions: [ContactSuggestion]
    let onQueryChanged: (String) -> Void

    @State private var currentInput: String = ""
    @State private var showSuggestions: Bool = false
    @FocusState private var isFocused: Bool

    public init(
        label: String,
        recipients: Binding<[String]>,
        suggestions: [ContactSuggestion] = [],
        onQueryChanged: @escaping (String) -> Void = { _ in }
    ) {
        self.label = label
        self._recipients = recipients
        self.suggestions = suggestions
        self.onQueryChanged = onQueryChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 4) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                RecipientFlowLayout(spacing: 4) {
                    ForEach(recipients, id: \.self) { recipient in
                        RecipientChip(email: recipient) {
                            recipients.removeAll { $0 == recipient }
                        }
                    }

                    TextField("", text: $currentInput)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .frame(minWidth: 100)
                        #if os(macOS)
                        .onSubmit { commitCurrentInput() }
                        #endif
                        .onChange(of: currentInput) { _, newValue in
                            onQueryChanged(newValue)
                            showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { commitCurrentInput() }
                        }
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { commitCurrentInput() }
                        #endif
                }
            }

            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            addRecipient(suggestion.email)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = suggestion.name {
                                    Text(name)
                                        .font(.body)
                                }
                                Text(suggestion.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        #if os(macOS)
                        .background(Color.accentColor.opacity(0.1))
                        #endif
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                .padding(.leading, 44)
            }
        }
    }

    private func commitCurrentInput() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && Self.isValidEmail(trimmed) {
            addRecipient(trimmed)
        }
    }

    private func addRecipient(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !recipients.contains(trimmed) else { return }
        recipients.append(trimmed)
        currentInput = ""
        showSuggestions = false
        onQueryChanged("")
    }

    /// Basic email validation.
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

/// A chip showing a recipient email with a remove button.
struct RecipientChip: View {
    let email: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(email)
                .font(.caption)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15))
        .clipShape(Capsule())
    }
}

/// Simple flow layout for wrapping chips.
struct RecipientFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions,
            sizes: sizes
        )
    }

    struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
