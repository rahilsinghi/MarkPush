import SwiftUI

// MARK: - Typography

extension Font {
    static let readerTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let readerH1 = Font.system(.title, design: .serif, weight: .bold)
    static let readerH2 = Font.system(.title2, design: .serif, weight: .semibold)
    static let readerH3 = Font.system(.title3, design: .default, weight: .semibold)
    static let readerBody = Font.system(.body, design: .default)
    static let readerCode = Font.system(.callout, design: .monospaced)
    static let cardTitle = Font.system(.headline, weight: .semibold)
    static let cardMeta = Font.system(.caption, weight: .regular)
}

// MARK: - Colors

extension Color {
    static let sourceClaude = Color.purple
    static let sourceCursor = Color.blue
    static let sourceManual = Color.gray

    static let annotationYellow = Color.yellow.opacity(0.3)
    static let annotationBlue = Color.blue.opacity(0.25)
    static let annotationGreen = Color.green.opacity(0.25)
    static let annotationPink = Color.pink.opacity(0.25)

    static let connected = Color.green
    static let disconnected = Color.red
    static let syncing = Color.orange
}

// MARK: - Animations

extension Animation {
    static let cardSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let drawerSlide = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let summaryReveal = Animation.easeOut(duration: 0.4)
}
