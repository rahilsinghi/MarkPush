import ComposableArchitecture
import Foundation
import Testing

@testable import MarkPush

@MainActor
struct AuthFeatureTests {

    // MARK: - Session Restore

    @Test
    func onAppear_withExistingSession_authenticates() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.restoreSession = {
                AuthSession(userId: "user-1", email: "test@example.com")
            }
        }

        await store.send(.onAppear)

        await store.receive(\.sessionRestored) {
            $0.isLoading = false
            $0.step = .authenticated
        }
    }

    @Test
    func onAppear_noSession_landing() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.restoreSession = { nil }
        }

        await store.send(.onAppear)

        await store.receive(\.sessionCheckFailed) {
            $0.step = .landing
        }
    }

    @Test
    func onAppear_ignoredIfNotChecking() async {
        var state = AuthFeature.State()
        state.step = .landing

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        await store.send(.onAppear)
        // No effects expected — returns .none when step != .checking
    }

    // MARK: - Email

    @Test
    func emailChanged_updatesEmail() async {
        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        }

        await store.send(.emailChanged("test@example.com")) {
            $0.email = "test@example.com"
        }
    }

    // MARK: - Send Magic Link

    @Test
    func sendMagicLink_emptyEmail_setsError() async {
        var state = AuthFeature.State()
        state.step = .landing
        state.email = ""

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        await store.send(.sendMagicLinkTapped) {
            $0.errorMessage = "Please enter your email address."
        }
    }

    @Test
    func sendMagicLink_whitespaceEmail_setsError() async {
        var state = AuthFeature.State()
        state.step = .landing
        state.email = "   "

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        await store.send(.sendMagicLinkTapped) {
            $0.errorMessage = "Please enter your email address."
        }
    }

    @Test
    func sendMagicLink_validEmail_sendsOTP() async {
        var state = AuthFeature.State()
        state.step = .landing
        state.email = "test@example.com"

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithOTP = { _ in }
        }

        await store.send(.sendMagicLinkTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.magicLinkSent) {
            $0.isLoading = false
            $0.step = .magicLinkSent
        }
    }

    @Test
    func sendMagicLink_failure_setsError() async {
        struct OTPError: LocalizedError {
            var errorDescription: String? { "Rate limit exceeded" }
        }

        var state = AuthFeature.State()
        state.step = .landing
        state.email = "test@example.com"

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithOTP = { _ in throw OTPError() }
        }

        await store.send(.sendMagicLinkTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.magicLinkFailed) {
            $0.isLoading = false
            $0.errorMessage = "Rate limit exceeded"
        }
    }

    // MARK: - Deep Link

    @Test
    func handleDeepLink_success_authenticates() async {
        var state = AuthFeature.State()
        state.step = .magicLinkSent

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.handleDeepLink = { _ in }
        }

        let url = URL(string: "markpush://auth/callback?code=test")!

        await store.send(.handleDeepLink(url)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.sessionRestored) {
            $0.isLoading = false
            $0.step = .authenticated
        }
    }

    @Test
    func handleDeepLink_failure_setsError() async {
        struct LinkError: LocalizedError {
            var errorDescription: String? { "Invalid or expired link" }
        }

        var state = AuthFeature.State()
        state.step = .magicLinkSent

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.handleDeepLink = { _ in throw LinkError() }
        }

        let url = URL(string: "markpush://auth/callback?code=expired")!

        await store.send(.handleDeepLink(url)) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.magicLinkFailed) {
            $0.isLoading = false
            $0.errorMessage = "Invalid or expired link"
        }
    }

    // MARK: - Resend & Navigation

    @Test
    func resendTapped_sendsOTPAgain() async {
        var state = AuthFeature.State()
        state.step = .magicLinkSent
        state.email = "test@example.com"

        let store = TestStore(initialState: state) {
            AuthFeature()
        } withDependencies: {
            $0.authClient.signInWithOTP = { _ in }
        }

        await store.send(.resendTapped) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(\.magicLinkSent) {
            $0.isLoading = false
            $0.step = .magicLinkSent
        }
    }

    @Test
    func useOtherEmailTapped_resetsToLanding() async {
        var state = AuthFeature.State()
        state.step = .magicLinkSent
        state.email = "test@example.com"
        state.errorMessage = "Some error"

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        await store.send(.useOtherEmailTapped) {
            $0.step = .landing
            $0.email = ""
            $0.errorMessage = nil
        }
    }

    @Test
    func dismissError_clearsErrorMessage() async {
        var state = AuthFeature.State()
        state.errorMessage = "Something went wrong"

        let store = TestStore(initialState: state) {
            AuthFeature()
        }

        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}
