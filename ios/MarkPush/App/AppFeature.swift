import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .feed
        var feed = FeedFeature.State()
        var settings = SettingsFeature.State()
    }

    enum Tab: Equatable {
        case feed
        case settings
    }

    enum Action {
        case tabSelected(Tab)
        case feed(FeedFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.feed, action: \.feed) {
            FeedFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .feed, .settings:
                return .none
            }
        }
    }
}

// MARK: - App View

import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            NavigationStack {
                FeedView(store: store.scope(state: \.feed, action: \.feed))
            }
            .tabItem {
                Label("Feed", systemImage: "doc.text")
            }
            .tag(AppFeature.Tab.feed)

            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(AppFeature.Tab.settings)
        }
    }
}
