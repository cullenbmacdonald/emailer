import Testing
import SwiftUI
@testable import Emailer

@Suite("DesignTokens")
@MainActor
struct DesignTokensTests {
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

    // MARK: - List Row Metrics

    @Test("macOS list row metrics are correct")
    func listRowMetrics() {
        #expect(ListRowMetrics.rowHeight == 64)
        #expect(ListRowMetrics.horizontalPadding == 12)
        #expect(ListRowMetrics.verticalPadding == 8)
        #expect(ListRowMetrics.accountDotSize == 8)
        #expect(ListRowMetrics.snoozeBadgeHeight == 20)
    }

    // MARK: - Color Existence

    @Test("Account colors are defined")
    func accountColors() {
        // Verify colors can be created without crashing
        _ = Color.accountWork
        _ = Color.accountPersonal1
        _ = Color.accountPersonal2
    }

    @Test("Semantic colors are defined")
    func semanticColors() {
        _ = Color.snooze
        _ = Color.newsletter
        _ = Color.filtered
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

    // MARK: - AccountFilter

    @Test("AccountFilter has 3 cases")
    func accountFilterCases() {
        #expect(AccountFilter.allCases.count == 3)
    }

    @Test("AccountFilter labels are correct")
    func accountFilterLabels() {
        #expect(AccountFilter.all.label == "All")
        #expect(AccountFilter.work.label == "Work")
        #expect(AccountFilter.personal.label == "Personal")
    }

    @Test("AccountFilter dotColor is nil for all, defined for others")
    func accountFilterDotColor() {
        #expect(AccountFilter.all.dotColor == nil)
        #expect(AccountFilter.work.dotColor != nil)
        #expect(AccountFilter.personal.dotColor != nil)
    }
}
