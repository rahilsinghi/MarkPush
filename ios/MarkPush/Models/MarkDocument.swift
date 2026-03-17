import Foundation
import SwiftData

/// A received markdown document stored locally.
@Model
final class MarkDocument {
    var id: UUID
    var title: String
    var content: String
    var receivedAt: Date
    var tags: [String]
    var wordCount: Int
    var isRead: Bool
    var isPinned: Bool
    var isArchived: Bool
    var source: String?
    var senderName: String?

    /// Estimated reading time in minutes.
    var readingTimeMinutes: Int {
        max(1, wordCount / 200)
    }

    /// First non-heading, non-empty line as excerpt.
    var excerpt: String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return String(trimmed.prefix(200))
            }
        }
        return ""
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        receivedAt: Date = .now,
        tags: [String] = [],
        wordCount: Int = 0,
        isRead: Bool = false,
        isPinned: Bool = false,
        isArchived: Bool = false,
        source: String? = nil,
        senderName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.receivedAt = receivedAt
        self.tags = tags
        self.wordCount = wordCount
        self.isRead = isRead
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.source = source
        self.senderName = senderName
    }

    /// Create from a decoded PushMessage.
    convenience init(from message: PushMessage, decryptedContent: String) {
        self.init(
            id: UUID(uuidString: message.id) ?? UUID(),
            title: message.title,
            content: decryptedContent,
            receivedAt: message.timestamp,
            tags: message.tags ?? [],
            wordCount: message.wordCount,
            source: message.source,
            senderName: message.senderName
        )
    }
}
