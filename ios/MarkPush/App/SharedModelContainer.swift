import SwiftData

/// Shared ModelContainer used by both the app and TCA dependencies.
/// Ensures SwiftData queries and insertions operate on the same store.
enum SharedModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: MarkDocument.self, Device.self, Annotation.self)
        } catch {
            fatalError("Failed to initialize shared ModelContainer: \(error)")
        }
    }()
}
