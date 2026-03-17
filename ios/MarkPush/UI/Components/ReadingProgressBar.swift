import SwiftUI

/// Thin reading progress indicator shown below the navigation bar.
struct ReadingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.mpProgressTrack)
                    .frame(height: 2)

                Rectangle()
                    .fill(Color.mpAccent)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 2)
                    .animation(.easeInOut(duration: 0.15), value: progress)
            }
        }
        .frame(height: 2)
        .accessibilityLabel("Reading progress: \(Int(progress * 100))%")
    }
}
