import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct MarkPushApp: App {
    static let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.store)
                .modelContainer(for: [MarkDocument.self, Device.self, Annotation.self])
        }
    }
}
