import SwiftUI

/// MarkPush design system colors from the design palette.
/// Light mode: warm parchment tones. Dark mode: deep warm blacks.
extension Color {
    // MARK: - Backgrounds

    /// Primary background — warm parchment (#F7F4EF light, #0F0E17 dark)
    static let mpBackground = Color("mpBackground")
    /// Card/surface background (#FFFFFF light, #1A1825 dark)
    static let mpSurface = Color("mpSurface")
    /// Code block background (#1E1D2E)
    static let mpCodeBackground = Color(hex: 0x1E1D2E)

    // MARK: - Accent

    /// Primary accent — deep indigo (#3730A3 light, #818CF8 dark)
    static let mpAccent = Color("mpAccent")
    /// Secondary accent — lighter indigo (#6366F1 light, #A5B4FC dark)
    static let mpAccentSecondary = Color("mpAccentSecondary")
    /// Accent glow for highlights (#6366F1)
    static let mpAccentGlow = Color(hex: 0x6366F1)

    // MARK: - Text

    /// Primary text (#0F0E17 light, #F0EFF4 dark)
    static let mpTextPrimary = Color("mpTextPrimary")
    /// Secondary text (#4A4458 light, #9491A0 dark)
    static let mpTextSecondary = Color("mpTextSecondary")
    /// Tertiary/meta text (#8F8B99 light, #6B6570 dark)
    static let mpTextTertiary = Color(hex: 0x8F8B99)

    // MARK: - Source Badge Colors

    static let mpSourceClaude = Color(hex: 0x6D28D9)
    static let mpSourceClaudeBg = Color(hex: 0xEDE9FE)
    static let mpSourceCursor = Color(hex: 0x0B6BCB)
    static let mpSourceCursorBg = Color(hex: 0xDBEAFE)
    static let mpSourceClaudeCode = Color(hex: 0x2563EB)
    static let mpSourceManual = Color(hex: 0x374151)
    static let mpSourceManualBg = Color(hex: 0xF3F4F6)

    // MARK: - Tag Colors

    static let mpTagBackground = Color(hex: 0xF3F2F7)
    static let mpTagText = Color(hex: 0x4A4458)

    // MARK: - Status

    static let mpConnected = Color(hex: 0x22C55E)
    static let mpDisconnected = Color(hex: 0xEF4444)
    static let mpUnreadDot = Color(hex: 0x6366F1)

    // MARK: - Reading Progress

    static let mpProgressBar = Color(hex: 0xA78BFA)
    static let mpProgressTrack = Color(hex: 0xE8E6DF)
}

// MARK: - Hex Color Init

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
