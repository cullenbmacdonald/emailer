import SwiftUI

// MARK: - Glass Effect View Modifiers

/// Defines which glass surface type to apply.
public enum GlassSurface: Sendable {
    /// Standard chrome surface (sidebar, toolbar, snooze picker, command palette)
    case chrome
    /// Toolbar action button group
    case toolbarGroup
    /// Snooze picker buttons
    case snoozePicker
    /// Account filter control
    case accountFilter
}

/// View modifier that applies Liquid Glass styling to chrome surfaces.
/// Content areas (email rows, body, cards, etc.) should NOT use this modifier.
///
/// On macOS, applies `.ultraThinMaterial` backgrounds for glass appearance.
/// On iOS, uses system materials appropriate for each surface type.
public struct GlassEffectModifier: ViewModifier {
    public let surface: GlassSurface
    public let tintColor: Color?

    public init(surface: GlassSurface, tintColor: Color? = nil) {
        self.surface = surface
        self.tintColor = tintColor
    }

    public func body(content: Content) -> some View {
        content
            .background(backgroundMaterial)
            .overlay(tintOverlay)
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
        switch surface {
        case .chrome:
            Rectangle().fill(.ultraThinMaterial)
        case .toolbarGroup:
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        case .snoozePicker:
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        case .accountFilter:
            Capsule()
                .fill(.thinMaterial)
        }
    }

    @ViewBuilder
    private var tintOverlay: some View {
        if let tintColor {
            switch surface {
            case .chrome:
                Rectangle()
                    .fill(tintColor.opacity(0.08))
            case .snoozePicker:
                RoundedRectangle(cornerRadius: 12)
                    .fill(tintColor.opacity(0.08))
            case .accountFilter:
                Capsule()
                    .fill(tintColor.opacity(0.10))
            case .toolbarGroup:
                RoundedRectangle(cornerRadius: 8)
                    .fill(tintColor.opacity(0.08))
            }
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Applies a glass effect appropriate for the given surface type.
    /// Use only on chrome/navigation surfaces, never on content.
    func glassEffect(surface: GlassSurface, tint: Color? = nil) -> some View {
        modifier(GlassEffectModifier(surface: surface, tintColor: tint))
    }

    /// Applies glass chrome styling (sidebar, toolbar).
    func glassChrome(tint: Color? = nil) -> some View {
        glassEffect(surface: .chrome, tint: tint)
    }
}

// MARK: - Glass Toolbar Button Style

/// A button style that uses a glass-like material background.
/// Used for toolbar action buttons (Reply, Archive, Snooze, etc.).
public struct GlassButtonStyle: ButtonStyle {
    public let tint: Color?

    public init(tint: Color? = nil) {
        self.tint = tint
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
            .overlay(tintOverlay(configuration: configuration))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private func tintOverlay(configuration: Configuration) -> some View {
        if let tint {
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(configuration.isPressed ? 0.15 : 0.08))
        }
    }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    /// Glass button style for toolbar actions.
    static var glass: GlassButtonStyle { GlassButtonStyle() }

    /// Glass button style with a specific tint color.
    static func glass(tint: Color) -> GlassButtonStyle {
        GlassButtonStyle(tint: tint)
    }
}

// MARK: - Glass Toolbar Group Container

/// Groups toolbar buttons together with a shared glass background.
/// Used for action groups like Reply/Archive/Snooze in the detail toolbar.
public struct GlassToolbarGroup<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 1) {
            content
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
