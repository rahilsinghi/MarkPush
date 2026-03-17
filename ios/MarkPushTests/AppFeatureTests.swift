import ComposableArchitecture
import Foundation
import Testing

@testable import MarkPush

@MainActor
struct AppFeatureTests {

    @Test
    func tabSelected_updatesTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tabSelected(.library)) {
            $0.selectedTab = .library
        }

        await store.send(.tabSelected(.settings)) {
            $0.selectedTab = .settings
        }

        await store.send(.tabSelected(.feed)) {
            $0.selectedTab = .feed
        }
    }

    @Test
    func signOutCompleted_resetsAuthToLanding() async {
        var state = AppFeature.State()
        state.auth.step = .authenticated

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.settings(.signOutCompleted)) {
            $0.auth = AuthFeature.State()
            $0.auth.step = .landing
        }
    }

    @Test
    func handleDeepLink_forwardsToAuth() async {
        var state = AppFeature.State()
        state.auth.step = .magicLinkSent

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.authClient.handleDeepLink = { _ in }
        }

        let url = URL(string: "markpush://auth/callback?code=test")!

        await store.send(.handleDeepLink(url))

        await store.receive(\.auth) {
            $0.auth.isLoading = true
            $0.auth.errorMessage = nil
        }

        await store.receive(\.auth) {
            $0.auth.isLoading = false
            $0.auth.step = .authenticated
        }
    }

    @Test
    func isAuthenticated_computedProperty() async {
        var state = AppFeature.State()

        // Default: checking — not authenticated
        #expect(state.isAuthenticated == false)

        state.auth.step = .landing
        #expect(state.isAuthenticated == false)

        state.auth.step = .magicLinkSent
        #expect(state.isAuthenticated == false)

        state.auth.step = .authenticated
        #expect(state.isAuthenticated == true)
    }
}
