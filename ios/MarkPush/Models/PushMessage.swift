import Foundation

/// Protocol version constant.
let protocolVersion = "1"

/// The primary payload sent from CLI to iOS app.
struct PushMessage: Codable, Equatable, Sendable {
    let version: String
    let type: String
    let id: String
    let timestamp: Date

    let title: String
    let tags: [String]?
    let source: String?
    let wordCount: Int

    let content: String
    let encrypted: Bool

    let senderID: String
    let senderName: String

    enum CodingKeys: String, CodingKey {
        case version, type, id, timestamp, title, tags, source
        case wordCount = "word_count"
        case content, encrypted
        case senderID = "sender_id"
        case senderName = "sender_name"
    }
}

/// Acknowledgment message sent back to the CLI.
struct AckMessage: Codable, Sendable {
    let version: String
    let type: String
    let id: String
    let timestamp: Date
    let refID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case version, type, id, timestamp
        case refID = "ref_id"
        case status
    }

    static func received(for messageID: String) -> AckMessage {
        AckMessage(
            version: protocolVersion,
            type: "ack",
            id: UUID().uuidString,
            timestamp: .now,
            refID: messageID,
            status: "received"
        )
    }
}

/// QR code pairing payload (uses short keys to minimize QR size).
struct PairInitPayload: Codable, Sendable {
    let version: String
    let secret: String
    let host: String
    let port: Int
    let senderID: String
    let senderName: String

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case secret = "s"
        case host = "h"
        case port = "p"
        case senderID = "id"
        case senderName = "name"
    }
}
