import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var readerFontSize: CGFloat = 17
        var showPairing: Bool = false
        var hasPairedDevice: Bool = false
    }

    enum Action {
        case onAppear
        case setFontSize(CGFloat)
        case showPairingTapped
        case dismissPairing
        case pairedDeviceChecked(Bool)
    }

    @Dependency(\.markPushClient) var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let hasPaired = await client.hasPairedDevice()
                    await send(.pairedDeviceChecked(hasPaired))
                }

            case .setFontSize(let size):
                state.readerFontSize = size
                return .none

            case .showPairingTapped:
                state.showPairing = true
                return .none

            case .dismissPairing:
                state.showPairing = false
                return .run { send in
                    let hasPaired = await client.hasPairedDevice()
                    await send(.pairedDeviceChecked(hasPaired))
                }

            case .pairedDeviceChecked(let value):
                state.hasPairedDevice = value
                return .none
            }
        }
    }
}
