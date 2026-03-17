import ComposableArchitecture
import Testing

@testable import MarkPush

@MainActor
struct PairingFeatureTests {
    @Test
    func startScanning() async {
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        }

        await store.send(.startScanning) {
            $0.step = .scanning
            $0.errorMessage = nil
        }
    }

    @Test
    func pairingSuccess() async {
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        } withDependencies: {
            $0.markPushClient.completePairing = { _ in "MacBook Pro" }
        }

        let payload = """
        {"v":"1","s":"dGVzdA==","h":"192.168.1.1","p":54321,"id":"cli-1","name":"MacBook Pro"}
        """

        await store.send(.qrCodeScanned(payload)) {
            $0.step = .pairing
        }

        await store.receive(.pairingCompleted("MacBook Pro")) {
            $0.step = .success
            $0.pairedDeviceName = "MacBook Pro"
        }
    }

    @Test
    func pairingFailure() async {
        let store = TestStore(initialState: PairingFeature.State()) {
            PairingFeature()
        }

        await store.send(.qrCodeScanned("invalid json")) {
            $0.step = .pairing
        }

        await store.receive(\.pairingFailed) {
            $0.step = .error
            $0.errorMessage = .some // any error message
        }
    }
}
