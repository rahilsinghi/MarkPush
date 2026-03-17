import ComposableArchitecture
import Foundation

@Reducer
struct PairingFeature {
    @ObservableState
    struct State: Equatable {
        var step: PairingStep = .instructions
        var pairedDeviceName: String?
        var errorMessage: String?
    }

    enum PairingStep: Equatable {
        case instructions
        case scanning
        case pairing
        case success
        case error
    }

    enum Action {
        case startScanning
        case qrCodeScanned(String)
        case pairingCompleted(String)
        case pairingFailed(String)
        case dismiss
    }

    @Dependency(\.markPushClient) var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startScanning:
                state.step = .scanning
                state.errorMessage = nil
                return .none

            case .qrCodeScanned(let data):
                state.step = .pairing
                return .run { send in
                    do {
                        let decoder = JSONDecoder()
                        guard let jsonData = data.data(using: .utf8) else {
                            await send(.pairingFailed("Invalid QR code data"))
                            return
                        }
                        let payload = try decoder.decode(PairInitPayload.self, from: jsonData)
                        let deviceName = try await client.completePairing(payload)
                        await send(.pairingCompleted(deviceName))
                    } catch {
                        await send(.pairingFailed(error.localizedDescription))
                    }
                }

            case .pairingCompleted(let deviceName):
                state.step = .success
                state.pairedDeviceName = deviceName
                return .none

            case .pairingFailed(let message):
                state.step = .error
                state.errorMessage = message
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
