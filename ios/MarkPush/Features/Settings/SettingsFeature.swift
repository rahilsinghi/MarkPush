import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var readerFontSize: CGFloat = 17
        var showPairing: Bool = false
        var hasPairedDevice: Bool = false
        var userEmail: String?
        var isSigningOut: Bool = false
    }

    enum Action {
        case onAppear
        case setFontSize(CGFloat)
        case showPairingTapped
        case dismissPairing
        case pairedDeviceChecked(Bool)
        case userEmailLoaded(String?)
        case signOutTapped
        case signOutCompleted
        case signOutFailed(String)
    }

    @Dependency(\.markPushClient) var client
    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let hasPaired = await client.hasPairedDevice()
                    await send(.pairedDeviceChecked(hasPaired))
                    let email = await authClient.currentUserEmail()
                    await send(.userEmailLoaded(email))
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

            case .userEmailLoaded(let email):
                state.userEmail = email
                return .none

            case .signOutTapped:
                state.isSigningOut = true
                return .run { send in
                    try await authClient.signOut()
                    await send(.signOutCompleted)
                } catch: { error, send in
                    await send(.signOutFailed(error.localizedDescription))
                }

            case .signOutCompleted:
                state.isSigningOut = false
                return .none // Parent (AppFeature) handles auth state reset

            case .signOutFailed:
                state.isSigningOut = false
                return .none
            }
        }
    }
}
