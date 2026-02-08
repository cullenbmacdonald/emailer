import Foundation

/// A command available in the Command Palette (Cmd+K).
public struct PaletteCommand: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let shortcutHint: String?
    public let category: Category
    public let action: @Sendable @MainActor () -> Void

    public enum Category: String, CaseIterable, Sendable {
        case navigation = "Navigation"
        case emailAction = "Email Actions"
        case compose = "Compose"
        case accountFilter = "Account Filter"
    }

    public init(
        id: String,
        title: String,
        icon: String,
        shortcutHint: String? = nil,
        category: Category,
        action: @escaping @Sendable @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.shortcutHint = shortcutHint
        self.category = category
        self.action = action
    }

    /// Fuzzy match the command against a query string.
    public func matches(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let lowered = query.lowercased()
        return title.lowercased().contains(lowered)
            || category.rawValue.lowercased().contains(lowered)
    }
}
