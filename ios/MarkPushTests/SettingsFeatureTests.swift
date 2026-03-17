import ComposableArchitecture
import Foundation
import Testing

@testable import MarkPush

@MainActor
struct SettingsFeatureTests {

    @Test
    func onAppear_loadsPairedStatusAndEmail() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.markPushClient.hasPairedDevice = { true }
            $0.authClient.currentUserEmail = { "rahil@example.com" }
        }

        await store.send(.onAppear)

        await store.receive(\.pairedDeviceChecked) {
            $0.hasPairedDevice = true
        }

        await store.receive(\.userEmailLoaded) {
            $0.userEmail = "rahil@example.com"
        }
    }

    @Test
    func setFontSize_updates() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.setFontSize(22)) {
            $0.readerFontSize = 22
        }
    }

    @Test
    func showPairingTapped_showsSheet() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.showPairingTapped) {
            $0.showPairing = true
        }
    }

    @Test
    func dismissPairing_hidesSheetAndRechecks() async {
        var state = SettingsFeature.State()
        state.showPairing = true

        let store = TestStore(initialState: state) {
            SettingsFeature()
        } withDependencies: {
            $0.markPushClient.hasPairedDevice = { true }
        }

        await store.send(.dismissPairing) {
            $0.showPairing = false
        }

        await store.receive(\.pairedDeviceChecked) {
            $0.hasPairedDevice = true
        }
    }

    @Test
    func signOutTapped_success() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.authClient.signOut = {}
        }

        await store.send(.signOutTapped) {
            $0.isSigningOut = true
        }

        await store.receive(\.signOutCompleted) {
            $0.isSigningOut = false
        }
    }

    @Test
    func signOutTapped_failure() async {
        struct SignOutError: LocalizedError {
            var errorDescription: String? { "Network error" }
        }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.authClient.signOut = { throw SignOutError() }
        }

        await store.send(.signOutTapped) {
            $0.isSigningOut = true
        }

        await store.receive(\.signOutFailed) {
            $0.isSigningOut = false
        }
    }

    @Test
    func userEmailLoaded_updatesState() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.userEmailLoaded("test@example.com")) {
            $0.userEmail = "test@example.com"
        }
    }

    @Test
    func pairedDeviceChecked_updatesState() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }

        await store.send(.pairedDeviceChecked(true)) {
            $0.hasPairedDevice = true
        }
    }
}
