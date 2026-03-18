import SwiftUI

/// Document card with three visual variants: unread, read, pinned.
/// Matches the MarkPush design system palette.
struct DocCard: View {
    let document: FeedFeature.DocumentState

    var body: some View {
        HStack(spacing: 0) {
            // Unread accent bar
            if !document.isRead {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.mpAccent)
                    .frame(width: 3)
                    .padding(.vertical, MPSpacing.sm)
            }

            VStack(alignment: .leading, spacing: MPSpacing.sm) {
                // Top row: source badge + time
                HStack {
                    if let source = document.source {
                        SourceBadge(source: source)
                    }
                    Spacer()
                    if document.isPinned {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.orange)
                            .accessibilityLabel("Pinned")
                    }
                    Text(document.receivedAt, style: .relative)
                        .font(MPFont.metadata)
                        .foregroundStyle(Color.mpTextTertiary)
                }

                // Title
                Text(document.title)
                    .font(document.isRead ? Font.custom("Lora-Regular", size: 19, relativeTo: .headline) : MPFont.cardTitle)
                    .foregroundStyle(Color.mpTextPrimary)
                    .lineLimit(2)

                // Excerpt
                if !document.excerpt.isEmpty {
                    Text(document.excerpt)
                        .font(MPFont.excerpt)
                        .foregroundStyle(Color.mpTextSecondary)
                        .lineLimit(2)
                }

                // Bottom row: reading time + word count + tags
                HStack(spacing: MPSpacing.md) {
                    HStack(spacing: MPSpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(document.readingTimeMinutes) min")
                    }
                    .font(MPFont.metadata)
                    .foregroundStyle(Color.mpTextTertiary)

                    Text("·")
                        .foregroundStyle(Color.mpTextTertiary)

                    Text("\(document.wordCount) words")
                        .font(MPFont.metadata)
                        .foregroundStyle(Color.mpTextTertiary)

                    if !document.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: MPSpacing.xs) {
                                ForEach(document.tags, id: \.self) { tag in
                                    TagPill(tag: tag)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.leading, document.isRead ? MPSpacing.cardPadding : MPSpacing.md)
            .padding(.trailing, MPSpacing.cardPadding)
            .padding(.vertical, MPSpacing.md)
        }
        .background(Color.mpSurface)
        .clipShape(RoundedRectangle(cornerRadius: MPSpacing.cardRadius))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(document.title), \(document.readingTimeMinutes) minute read, \(document.isRead ? "read" : "unread")")
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: String

    var body: some View {
        Text(source)
            .font(MPFont.badge)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, MPSpacing.sm)
            .padding(.vertical, 3)
            .foregroundStyle(badgeTextColor)
            .background(badgeBgColor, in: Capsule())
            .accessibilityLabel("Source: \(source)")
    }

    private var badgeTextColor: Color {
        switch source.lowercased() {
        case "claude": .mpSourceClaude
        case "cursor": .mpSourceCursor
        case "claude code": .mpSourceClaudeCode
        default: .mpSourceManual
        }
    }

    private var badgeBgColor: Color {
        switch source.lowercased() {
        case "claude": .mpSourceClaudeBg
        case "cursor": .mpSourceCursorBg
        default: .mpSourceManualBg
        }
    }
}

// MARK: - Tag Pill

struct TagPill: View {
    let tag: String

    var body: some View {
        Text("#\(tag)")
            .font(MPFont.tagPill)
            .foregroundStyle(Color.mpTagText)
            .padding(.horizontal, MPSpacing.sm)
            .padding(.vertical, 3)
            .background(Color.mpTagBackground, in: Capsule())
            .accessibilityLabel("Tag: \(tag)")
    }
}
