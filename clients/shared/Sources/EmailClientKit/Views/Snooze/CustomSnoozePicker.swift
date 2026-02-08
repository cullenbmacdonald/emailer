import SwiftUI

/// Custom date/time picker for arbitrary future snooze dates.
public struct CustomSnoozePicker: View {
    public let onSnooze: (Date) -> Void
    public let onDismiss: () -> Void

    @State private var selectedDate: Date = {
        // Default to tomorrow at 9am
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
    }()

    /// The earliest allowed date (now + 1 minute).
    private var minimumDate: Date {
        Date().addingTimeInterval(60)
    }

    /// Whether the selected date is valid (in the future).
    private var isValid: Bool {
        selectedDate > Date()
    }

    public init(
        onSnooze: @escaping (Date) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onSnooze = onSnooze
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Pick a Date & Time")
                    .font(.headline)
                    .foregroundStyle(Color.snooze)
                Spacer()
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            DatePicker(
                "Snooze until",
                selection: $selectedDate,
                in: minimumDate...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            HStack {
                Text(SnoozeOption.formattedDate(selectedDate))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Snooze") {
                    onSnooze(selectedDate)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.snooze)
                .disabled(!isValid)
                #if os(macOS)
                .keyboardShortcut(.return, modifiers: [])
                #endif
            }
        }
        .padding(Spacing.xl)
        .frame(minWidth: 320, idealWidth: 360)
    }
}

#Preview("CustomSnoozePicker") {
    CustomSnoozePicker(
        onSnooze: { date in print("Snooze until \(date)") },
        onDismiss: {}
    )
}
