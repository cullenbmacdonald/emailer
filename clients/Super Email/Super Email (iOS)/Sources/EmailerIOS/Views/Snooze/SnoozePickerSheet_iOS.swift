import SwiftUI
import EmailClientKit

#if os(iOS)
/// iOS snooze picker presented as a bottom sheet with medium detent.
/// Wraps the preset options and custom date picker in an iOS-native layout.
struct SnoozePickerSheet_iOS: View {
    let onSnooze: (Date) -> Void
    let onDismiss: () -> Void

    @State private var showCustomPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SnoozeOption.presets) { option in
                        Button {
                            onSnooze(option.targetDate)
                        } label: {
                            HStack(spacing: Spacing.md) {
                                Image(systemName: option.icon)
                                    .foregroundStyle(Color.snooze)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.label)
                                        .foregroundStyle(.primary)
                                    Text(SnoozeOption.formattedDate(option.targetDate))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showCustomPicker = true
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(Color.snooze)
                                .frame(width: 24)

                            Text("Custom...")
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Snooze until...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
        .sheet(isPresented: $showCustomPicker) {
            CustomSnoozeSheet_iOS(
                onSnooze: onSnooze,
                onDismiss: { showCustomPicker = false }
            )
        }
    }
}

/// iOS custom date picker sheet for arbitrary future snooze dates.
struct CustomSnoozeSheet_iOS: View {
    let onSnooze: (Date) -> Void
    let onDismiss: () -> Void

    @State private var selectedDate: Date = {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
    }()

    private var minimumDate: Date {
        Date().addingTimeInterval(60)
    }

    private var isValid: Bool {
        selectedDate > Date()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
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
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Pick a Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview("Snooze Picker Sheet") {
    Text("Background")
        .sheet(isPresented: .constant(true)) {
            SnoozePickerSheet_iOS(
                onSnooze: { date in print("Snooze until \(date)") },
                onDismiss: {}
            )
        }
}

#Preview("Custom Snooze Picker") {
    CustomSnoozeSheet_iOS(
        onSnooze: { date in print("Snooze until \(date)") },
        onDismiss: {}
    )
}
#endif
