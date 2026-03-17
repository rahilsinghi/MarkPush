import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct MarkPushApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: MarkDocument.self, Device.self, Annotation.self)
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .modelContainer(container)
        }
    }
}
