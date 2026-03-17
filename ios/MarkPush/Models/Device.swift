import Foundation
import SwiftData

/// A paired CLI device.
@Model
final class Device {
    var id: UUID
    var name: String
    var senderID: String
    var pairedAt: Date

    init(id: UUID = UUID(), name: String, senderID: String, pairedAt: Date = .now) {
        self.id = id
        self.name = name
        self.senderID = senderID
        self.pairedAt = pairedAt
    }
}
