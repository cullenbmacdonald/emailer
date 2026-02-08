import SwiftUI

/// Popover snooze picker with preset options and custom date/time.
/// Presented from the toolbar Snooze button or S key.
public struct SnoozePickerView: View {
    public let onSnooze: (Date) -> Void
    public let onDismiss: () -> Void

    @State private var showCustomPicker = false

    public init(
        onSnooze: @escaping (Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onSnooze = onSnooze
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Snooze until...")
                .font(.headline)
                .foregroundStyle(Color.snooze)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.sm)

            ForEach(Array(SnoozeOption.presets.enumerated()), id: \.element.id) { index, option in
                presetButton(option: option, shortcutKey: "\(index + 1)")
            }

            Divider()
                .padding(.vertical, Spacing.xs)

            Button {
                showCustomPicker = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color.snooze)
                        .frame(width: 20)
                    Text("Pick a Date & Time")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("C")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, Spacing.sm)
        .frame(width: 260)
        #if os(macOS)
        .onKeyPress("1") { selectPreset(0); return .handled }
        .onKeyPress("2") { selectPreset(1); return .handled }
        .onKeyPress("3") { selectPreset(2); return .handled }
        .onKeyPress("c") { showCustomPicker = true; return .handled }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        #endif
        .sheet(isPresented: $showCustomPicker) {
            CustomSnoozePicker(
                onSnooze: onSnooze,
                onDismiss: { showCustomPicker = false }
            )
        }
    }

    private func presetButton(option: SnoozeOption, shortcutKey: String) -> some View {
        Button {
            onSnooze(option.targetDate)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: option.icon)
                    .foregroundStyle(Color.snooze)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .foregroundStyle(.primary)
                    Text(SnoozeOption.formattedDate(option.targetDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(shortcutKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectPreset(_ index: Int) {
        let presets = SnoozeOption.presets
        guard index < presets.count else { return }
        onSnooze(presets[index].targetDate)
    }
}

#Preview("SnoozePickerView") {
    SnoozePickerView(
        onSnooze: { date in print("Snooze until \(date)") },
        onDismiss: {}
    )
    .frame(width: 300, height: 300)
}
