import Testing
import SwiftUI
@testable import EmailerIOSLib

// MARK: - IOSDesignTokens Tests

@Suite("IOSDesignTokens")
struct DesignTokensTests {
    // MARK: Spacing scale (4pt grid)

    @Test("Spacing tokens follow 4pt grid")
    func spacingTokensFollow4ptGrid() {
        #expect(IOSDesignTokens.spaceXS == 4)
        #expect(IOSDesignTokens.spaceSM == 8)
        #expect(IOSDesignTokens.spaceMD == 12)
        #expect(IOSDesignTokens.spaceLG == 16)
        #expect(IOSDesignTokens.spaceXL == 20)
        #expect(IOSDesignTokens.space2XL == 24)
        #expect(IOSDesignTokens.space3XL == 32)
        #expect(IOSDesignTokens.space4XL == 48)
    }

    @Test("All spacing values are multiples of 4")
    func allSpacingValuesAreMultiplesOf4() {
        let spacings: [CGFloat] = [
            IOSDesignTokens.spaceXS,
            IOSDesignTokens.spaceSM,
            IOSDesignTokens.spaceMD,
            IOSDesignTokens.spaceLG,
            IOSDesignTokens.spaceXL,
            IOSDesignTokens.space2XL,
            IOSDesignTokens.space3XL,
            IOSDesignTokens.space4XL
        ]
        for spacing in spacings {
            #expect(spacing.truncatingRemainder(dividingBy: 4) == 0,
                    "Spacing \(spacing) is not a multiple of 4")
        }
    }

    // MARK: iOS-specific dimensions

    @Test("Account dot diameter is 10pt (vs 8pt macOS)")
    func accountDotDiameterIs10pt() {
        #expect(IOSDesignTokens.accountDotDiameter == 10)
    }

    @Test("Row height is 72pt (vs 64pt macOS)")
    func rowHeightIs72pt() {
        #expect(IOSDesignTokens.rowHeight == 72)
    }

    @Test("Snooze badge height is 22pt (vs 20pt macOS)")
    func snoozeBadgeHeightIs22pt() {
        #expect(IOSDesignTokens.snoozeBadgeHeight == 22)
    }

    @Test("Badge height is 22pt")
    func badgeHeightIs22pt() {
        #expect(IOSDesignTokens.badgeHeight == 22)
    }

    @Test("Row horizontal padding is 16pt (vs 12pt macOS)")
    func rowHorizontalPaddingIs16pt() {
        #expect(IOSDesignTokens.rowHorizontalPadding == 16)
    }

    @Test("Row vertical padding is 10pt (vs 8pt macOS)")
    func rowVerticalPaddingIs10pt() {
        #expect(IOSDesignTokens.rowVerticalPadding == 10)
    }

    @Test("Empty state icon size is 56pt (vs 48pt macOS)")
    func emptyStateIconSizeIs56pt() {
        #expect(IOSDesignTokens.emptyStateIconSize == 56)
    }

    @Test("Empty state max width is 320pt")
    func emptyStateMaxWidthIs320pt() {
        #expect(IOSDesignTokens.emptyStateMaxWidth == 320)
    }
}

// MARK: - Color Hex Initializer Tests

@Suite("Color Hex Initializer")
struct ColorHexTests {
    @Test("Color from hex string creates valid color")
    func colorFromHexString() {
        // Should not crash — basic initialization test
        let color = Color(hex: "#3B82F6")
        #expect(color != Color.clear)
    }

    @Test("Color from hex without hash prefix")
    func colorFromHexWithoutHash() {
        let color = Color(hex: "3B82F6")
        #expect(color != Color.clear)
    }

    @Test("All fallback colors are defined")
    func allFallbackColorsDefined() {
        // Verify all fallback color statics exist and can be referenced
        let colors: [Color] = [
            .accountWorkFallback,
            .accountPersonal1Fallback,
            .accountPersonal2Fallback,
            .snoozeFallback,
            .newsletterFallback,
            .filteredFallback,
            .successFallback,
            .recBookFallback,
            .recMovieFallback,
            .recMusicFallback,
            .recArticleFallback,
            .recPodcastFallback,
            .recOtherFallback
        ]
        #expect(colors.count == 13)
    }
}
