#if os(macOS)
import SwiftUI

/// Floating command palette overlay (Cmd+K).
/// Glass background, fuzzy search, keyboard-navigable results.
public struct CommandPaletteView: View {
    @Environment(FocusCoordinator.self) private var focusCoordinator

    public let commands: [PaletteCommand]

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool

    public init(commands: [PaletteCommand]) {
        self.commands = commands
    }

    private var filteredCommands: [PaletteCommand] {
        commands.filter { $0.matches(searchText) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Type a command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        executeSelected()
                    }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)

            Divider()

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandItemView(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .id(command.id)
                            .onTapGesture {
                                command.action()
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .onChange(of: selectedIndex) { _, newIndex in
                    if let cmd = filteredCommands[safe: newIndex] {
                        proxy.scrollTo(cmd.id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 500)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            searchText = ""
            selectedIndex = 0
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            focusCoordinator.dismissCommandPalette()
            return .handled
        }
    }

    private func executeSelected() {
        guard let command = filteredCommands[safe: selectedIndex] else { return }
        command.action()
    }
}

/// A single row in the command palette results.
struct CommandItemView: View {
    let command: PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: command.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(command.title)
                .font(.body)

            Spacer()

            if let hint = command.shortcutHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                    )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(command.title)\(command.shortcutHint.map { ", shortcut \($0)" } ?? "")")
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Command Palette") {
    CommandPaletteView(commands: [
        PaletteCommand(id: "1", title: "Go to Action Queue", icon: "tray.and.arrow.down.fill", shortcutHint: "Cmd+1", category: .navigation) {},
        PaletteCommand(id: "2", title: "Go to Reading Queue", icon: "book.fill", shortcutHint: "Cmd+2", category: .navigation) {},
        PaletteCommand(id: "3", title: "Archive", icon: "archivebox", shortcutHint: "E", category: .emailAction) {},
    ])
    .environment(FocusCoordinator())
    .frame(width: 600, height: 400)
}
#endif
