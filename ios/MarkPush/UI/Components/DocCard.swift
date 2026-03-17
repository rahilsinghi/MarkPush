import SwiftUI

struct DocCard: View {
    let document: FeedFeature.DocumentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let source = document.source {
                    SourceBadge(source: source)
                }
                Spacer()
                Text(document.receivedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(document.title)
                .font(.headline)
                .lineLimit(2)

            if !document.excerpt.isEmpty {
                Text(document.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 12) {
                Label("\(document.readingTimeMinutes) min read", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !document.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(document.tags, id: \.self) { tag in
                                TagPill(tag: tag)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .leading) {
            if !document.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                    .offset(x: -16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.title), \(document.readingTimeMinutes) minute read, \(document.isRead ? "read" : "unread")")
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: String

    var body: some View {
        Text(source)
            .font(.caption2.bold())
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
            .accessibilityLabel("Source: \(source)")
    }

    private var badgeColor: Color {
        switch source.lowercased() {
        case "claude": .purple
        case "cursor": .blue
        case "windsurf": .teal
        default: .gray
        }
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.fill.tertiary, in: Capsule())
            .accessibilityLabel("Tag: \(tag)")
    }
}
