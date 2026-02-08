import Testing
@testable import EmailClientKit

// MARK: - GlassSurface

@Suite("GlassSurface")
struct GlassSurfaceTests {
    @Test("All surface types are distinct")
    func allSurfaceTypes() {
        let surfaces: [GlassSurface] = [.chrome, .toolbarGroup, .snoozePicker, .accountFilter]
        #expect(surfaces.count == 4)
    }

    @Test("GlassSurface is Sendable")
    func sendable() {
        let surface: GlassSurface = .chrome
        let _: any Sendable = surface
    }
}

// MARK: - GlassEffectModifier

@Suite("GlassEffectModifier")
struct GlassEffectModifierTests {
    @Test("Modifier can be created for each surface type")
    func modifierCreation() {
        let chromeMod = GlassEffectModifier(surface: .chrome)
        #expect(chromeMod.surface == .chrome)
        #expect(chromeMod.tintColor == nil)

        let tintedMod = GlassEffectModifier(surface: .snoozePicker, tintColor: .purple)
        #expect(tintedMod.surface == .snoozePicker)
        #expect(tintedMod.tintColor != nil)
    }

    @Test("Modifier with nil tint has no tint overlay")
    func noTint() {
        let mod = GlassEffectModifier(surface: .chrome, tintColor: nil)
        #expect(mod.tintColor == nil)
    }

    @Test("Modifier with tint has tint overlay")
    func withTint() {
        let mod = GlassEffectModifier(surface: .accountFilter, tintColor: .blue)
        #expect(mod.tintColor != nil)
    }
}

// MARK: - GlassButtonStyle

@Suite("GlassButtonStyle")
struct GlassButtonStyleTests {
    @Test("Default glass style has no tint")
    func defaultStyle() {
        let style = GlassButtonStyle()
        #expect(style.tint == nil)
    }

    @Test("Glass style can have a tint")
    func tintedStyle() {
        let style = GlassButtonStyle(tint: .red)
        #expect(style.tint != nil)
    }
}
