import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .feed
        var feed = FeedFeature.State()
        var library = LibraryFeature.State()
        var settings = SettingsFeature.State()
    }

    enum Tab: Equatable {
        case feed
        case library
        case settings
    }

    enum Action {
        case tabSelected(Tab)
        case feed(FeedFeature.Action)
        case library(LibraryFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.feed, action: \.feed) {
            FeedFeature()
        }
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none
            case .feed, .library, .settings:
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
                LibraryView(store: store.scope(state: \.library, action: \.library))
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }
            .tag(AppFeature.Tab.library)

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
