import Foundation
import SwiftData

/// A user highlight or note on a document.
@Model
final class Annotation {
    var id: UUID
    var documentID: UUID
    var selectedText: String
    var note: String?
    var color: String  // "yellow", "blue", "green", "pink"
    var rangeLocation: Int
    var rangeLength: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        documentID: UUID,
        selectedText: String,
        note: String? = nil,
        color: String = "yellow",
        rangeLocation: Int = 0,
        rangeLength: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentID = documentID
        self.selectedText = selectedText
        self.note = note
        self.color = color
        self.rangeLocation = rangeLocation
        self.rangeLength = rangeLength
        self.createdAt = createdAt
    }
}
