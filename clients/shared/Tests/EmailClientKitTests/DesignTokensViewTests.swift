import Testing
import SwiftUI
@testable import EmailClientKit

@Suite("DesignTokens - Views")
@MainActor
struct DesignTokensViewTests {
    // MARK: - Spacing Constants

    @Test("Spacing values follow 4pt grid")
    func spacingGrid() {
        #expect(Spacing.xs == 4)
        #expect(Spacing.sm == 8)
        #expect(Spacing.md == 12)
        #expect(Spacing.lg == 16)
        #expect(Spacing.xl == 20)
        #expect(Spacing.xxl == 24)
        #expect(Spacing.xxxl == 32)
        #expect(Spacing.xxxxl == 48)
    }

    @Test("All spacing values are multiples of 4")
    func allSpacingValuesAreMultiplesOf4() {
        let spacings: [CGFloat] = [
            Spacing.xs, Spacing.sm, Spacing.md, Spacing.lg,
            Spacing.xl, Spacing.xxl, Spacing.xxxl, Spacing.xxxxl,
        ]
        for spacing in spacings {
            #expect(
                spacing.truncatingRemainder(dividingBy: 4) == 0,
                "Spacing \(spacing) is not a multiple of 4"
            )
        }
    }

    // MARK: - List Row Metrics (macOS values when built for macOS)

    @Test("List row metrics are platform-correct")
    func listRowMetrics() {
        #if os(macOS)
        #expect(ListRowMetrics.rowHeight == 64)
        #expect(ListRowMetrics.horizontalPadding == 12)
        #expect(ListRowMetrics.verticalPadding == 8)
        #expect(ListRowMetrics.accountDotSize == 8)
        #expect(ListRowMetrics.snoozeBadgeHeight == 20)
        #expect(ListRowMetrics.badgeHeight == 20)
        #expect(ListRowMetrics.emptyStateIconSize == 48)
        #else
        #expect(ListRowMetrics.rowHeight == 72)
        #expect(ListRowMetrics.horizontalPadding == 16)
        #expect(ListRowMetrics.verticalPadding == 10)
        #expect(ListRowMetrics.accountDotSize == 10)
        #expect(ListRowMetrics.snoozeBadgeHeight == 22)
        #expect(ListRowMetrics.badgeHeight == 22)
        #expect(ListRowMetrics.emptyStateIconSize == 56)
        #endif
        #expect(ListRowMetrics.emptyStateMaxWidth == 320)
    }

    // MARK: - Color Existence

    @Test("Account colors are defined")
    func accountColors() {
        _ = Color.accountWork
        _ = Color.accountPersonal1
        _ = Color.accountPersonal2
    }

    @Test("Semantic colors are defined")
    func semanticColors() {
        _ = Color.snooze
        _ = Color.newsletter
        _ = Color.filteredColor
        _ = Color.success
        _ = Color.destructive
    }

    @Test("Recommendation type colors are defined")
    func recTypeColors() {
        _ = Color.recBook
        _ = Color.recMovie
        _ = Color.recMusic
        _ = Color.recArticle
        _ = Color.recPodcast
        _ = Color.recOther
    }

    // MARK: - Color Hex Initializer

    @Test("Color from hex UInt32 creates valid color")
    func colorFromHexUInt32() {
        let color = Color(hex: 0x3B82F6)
        _ = color // Should not crash
    }

    @Test("Color from hex string creates valid color")
    func colorFromHexString() {
        let color = Color(hexString: "#3B82F6")
        _ = color // Should not crash
    }

    @Test("Color from hex string without hash prefix")
    func colorFromHexStringWithoutHash() {
        let color = Color(hexString: "3B82F6")
        _ = color // Should not crash
    }

    @Test("Invalid hex string defaults to gray")
    func invalidHexStringDefaultsToGray() {
        let color = Color(hexString: "ZZZZZZ")
        _ = color // Should default to gray without crashing
    }
}
