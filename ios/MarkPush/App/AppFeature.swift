import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var auth = AuthFeature.State()
        var selectedTab: Tab = .feed
        var feed = FeedFeature.State()
        var library = LibraryFeature.State()
        var settings = SettingsFeature.State()

        var isAuthenticated: Bool {
            auth.step == .authenticated
        }
    }

    enum Tab: Equatable {
        case feed
        case library
        case settings
    }

    enum Action {
        case auth(AuthFeature.Action)
        case handleDeepLink(URL)
        case tabSelected(Tab)
        case feed(FeedFeature.Action)
        case library(LibraryFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }
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
            case .handleDeepLink(let url):
                return .send(.auth(.handleDeepLink(url)))

            case .settings(.signOutCompleted):
                state.auth = AuthFeature.State()
                state.auth.step = .landing
                return .none

            case .tabSelected(let tab):
                state.selectedTab = tab
                return .none

            case .auth, .feed, .library, .settings:
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
        Group {
            if store.isAuthenticated {
                mainTabView
            } else {
                AuthView(store: store.scope(state: \.auth, action: \.auth))
            }
        }
    }

    private var mainTabView: some View {
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
