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
                .modelContainer(SharedModelContainer.shared)
                .onOpenURL { url in
                    Self.store.send(.handleDeepLink(url))
                }
        }
    }
}
