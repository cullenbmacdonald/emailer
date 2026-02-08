import Foundation

/// A preset snooze option with a label and computed target date.
public struct SnoozeOption: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let icon: String
    public let computeDate: @Sendable () -> Date

    /// The computed target date for this option.
    public var targetDate: Date { computeDate() }

    public init(id: String, label: String, icon: String, computeDate: @escaping @Sendable () -> Date) {
        self.id = id
        self.label = label
        self.icon = icon
        self.computeDate = computeDate
    }

    /// Standard preset options.
    public static var presets: [SnoozeOption] {
        [twoHours, tomorrowMorning, nextWeek]
    }

    /// Snooze for 2 hours from now.
    public static let twoHours = SnoozeOption(
        id: "2hours",
        label: "2 Hours",
        icon: "clock"
    ) {
        Date().addingTimeInterval(2 * 60 * 60)
    }

    /// Snooze until tomorrow at 9am.
    public static let tomorrowMorning = SnoozeOption(
        id: "tomorrow",
        label: "Tomorrow 9am",
        icon: "sunrise"
    ) {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!
    }

    /// Snooze until next Monday at 9am.
    public static let nextWeek = SnoozeOption(
        id: "nextweek",
        label: "Next Week",
        icon: "calendar"
    ) {
        let calendar = Calendar.current
        let today = Date()
        // Find next Monday
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (9 - weekday) % 7 // Sunday=1, Monday=2
        let adjustedDays = daysUntilMonday == 0 ? 7 : daysUntilMonday
        let nextMonday = calendar.date(byAdding: .day, value: adjustedDays, to: calendar.startOfDay(for: today))!
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: nextMonday)!
    }

    /// Format the target date as secondary text.
    public static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
