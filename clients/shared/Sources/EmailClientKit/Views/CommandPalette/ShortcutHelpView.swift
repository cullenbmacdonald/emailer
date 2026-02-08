#if os(macOS)
import SwiftUI

/// Overlay showing all available keyboard shortcuts (? key).
public struct ShortcutHelpView: View {
    @Environment(FocusCoordinator.self) private var focusCoordinator

    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.bold())
                Spacer()
                Button {
                    focusCoordinator.dismissShortcutHelp()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }

            HStack(alignment: .top, spacing: Spacing.xl) {
                shortcutGroup("Navigation", shortcuts: [
                    ("J", "Next email"),
                    ("K", "Previous email"),
                    ("Enter", "Open email"),
                    ("Esc", "Return to list"),
                    ("Tab", "Cycle focus"),
                    ("/", "Search"),
                    ("?", "This help"),
                ])

                Divider()

                shortcutGroup("Actions", shortcuts: [
                    ("R", "Reply"),
                    ("A", "Reply All"),
                    ("F", "Forward"),
                    ("E", "Archive"),
                    ("S", "Snooze"),
                    ("M", "Move/Reclassify"),
                    ("#", "Trash"),
                    ("U", "Toggle read/unread"),
                ])

                Divider()

                shortcutGroup("Global", shortcuts: [
                    ("Cmd+1-5", "Switch views"),
                    ("Cmd+D", "Daily Digest"),
                    ("Cmd+K", "Command Palette"),
                    ("Cmd+N", "New email"),
                    ("Cmd+Enter", "Send email"),
                    ("Cmd+Shift+1", "Work only"),
                    ("Cmd+Shift+2", "Personal only"),
                    ("Cmd+Shift+3", "All accounts"),
                ])
            }
        }
        .padding(Spacing.xl)
        .frame(width: 660)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onKeyPress(.escape) {
            focusCoordinator.dismissShortcutHelp()
            return .handled
        }
    }

    @ViewBuilder
    private func shortcutGroup(_ title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.headline)
                .padding(.bottom, Spacing.xs)

            ForEach(shortcuts, id: \.0) { key, description in
                HStack {
                    Text(key)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)
                        )
                        .frame(minWidth: 60, alignment: .trailing)

                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Shortcut Help") {
    ShortcutHelpView()
        .environment(FocusCoordinator())
        .frame(width: 700, height: 400)
}
#endif
