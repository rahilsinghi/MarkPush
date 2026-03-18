import ComposableArchitecture
import Foundation
import SwiftData

/// TCA dependency for persisting documents to SwiftData.
struct PersistenceClient: Sendable {
    /// Save a received document to the local library.
    var saveDocument: @Sendable (
        _ id: UUID,
        _ title: String,
        _ content: String,
        _ source: String?,
        _ tags: [String],
        _ wordCount: Int,
        _ senderName: String,
        _ receivedAt: Date
    ) async throws -> Void
}

extension PersistenceClient: DependencyKey {
    static let liveValue = PersistenceClient(
        saveDocument: { id, title, content, source, tags, wordCount, senderName, receivedAt in
            // Create a fresh context — thread-safe, not tied to main actor.
            let context = ModelContext(SharedModelContainer.shared)
            let doc = MarkDocument(
                id: id,
                title: title,
                content: content,
                receivedAt: receivedAt,
                tags: tags,
                wordCount: wordCount,
                source: source,
                senderName: senderName
            )
            context.insert(doc)
            try context.save()
        }
    )

    static let testValue = PersistenceClient(
        saveDocument: { _, _, _, _, _, _, _, _ in }
    )
}

extension DependencyValues {
    var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
