import SwiftUI

/// MarkPush design system typography.
/// Uses custom fonts: Fraunces (headings), Lora (card titles), Inter (body), JetBrains Mono (code).
enum MPFont {
    // MARK: - Headings (Fraunces / Playfair Display)

    /// App title — Fraunces Bold 26pt
    static let appTitle = Font.custom("Fraunces-Bold", size: 26, relativeTo: .largeTitle)
    /// Reader H1 — Playfair Display Bold 26pt
    static let readerH1 = Font.custom("PlayfairDisplay-Bold", size: 26, relativeTo: .title)
    /// Reader H2 — Playfair Display Bold 22pt
    static let readerH2 = Font.custom("PlayfairDisplay-Bold", size: 22, relativeTo: .title2)
    /// Reader H3 — Inter SemiBold 18pt
    static let readerH3 = Font.system(size: 18, weight: .semibold, design: .default)

    // MARK: - Card & Body (Lora / Inter)

    /// Card title — Lora SemiBold 19pt
    static let cardTitle = Font.custom("Lora-SemiBold", size: 19, relativeTo: .headline)
    /// Body text — Inter Regular 15pt
    static let body = Font.custom("Inter-Regular", size: 15, relativeTo: .body)
    /// Body medium — Inter Medium 15pt
    static let bodyMedium = Font.custom("Inter-Medium", size: 15, relativeTo: .body)
    /// Reader body — Lora Regular 17pt
    static let readerBody = Font.custom("Lora-Regular", size: 17, relativeTo: .body)
    /// Excerpt — Inter Regular 15pt secondary
    static let excerpt = Font.custom("Inter-Regular", size: 15, relativeTo: .subheadline)

    // MARK: - Code (JetBrains Mono)

    /// Code — JetBrains Mono Regular 13.5pt
    static let code = Font.custom("JetBrainsMono-Regular", size: 13.5, relativeTo: .callout)
    /// Code secondary — JetBrains Mono Regular 12pt
    static let codeSmall = Font.custom("JetBrainsMono-Regular", size: 12, relativeTo: .caption)

    // MARK: - UI Chrome (Inter)

    /// Section header — Inter Medium 11pt uppercase wide tracking
    static let sectionHeader = Font.custom("Inter-Medium", size: 11, relativeTo: .caption)
    /// Tag pill — Inter Medium 11pt
    static let tagPill = Font.custom("Inter-Medium", size: 11, relativeTo: .caption2)
    /// Metadata — Inter Regular 12pt
    static let metadata = Font.custom("Inter-Regular", size: 12, relativeTo: .caption)
    /// Badge text — Inter SemiBold 10pt
    static let badge = Font.system(size: 10, weight: .semibold, design: .default)

    // MARK: - Fallbacks (if custom fonts not loaded)

    /// System serif for reader content
    static func readerBodySystem(size: CGFloat) -> Font {
        .system(size: size, design: .serif)
    }

    /// System monospaced for code
    static func codeSystem(size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

// MARK: - View modifiers for consistent text styling

extension View {
    func mpSectionHeader() -> some View {
        self
            .font(MPFont.sectionHeader)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Color.mpTextTertiary)
    }
}
