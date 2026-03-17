import ComposableArchitecture
import Foundation

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var step: Step = .checking
        var email: String = ""
        var isLoading: Bool = false
        var errorMessage: String?

        enum Step: Equatable {
            case checking
            case landing
            case magicLinkSent
            case authenticated
        }
    }

    enum Action {
        case onAppear
        case emailChanged(String)
        case sendMagicLinkTapped
        case magicLinkSent
        case magicLinkFailed(String)
        case handleDeepLink(URL)
        case sessionRestored
        case sessionCheckFailed
        case resendTapped
        case useOtherEmailTapped
        case dismissError
    }

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.step == .checking else { return .none }
                return .run { send in
                    if let _ = await authClient.restoreSession() {
                        await send(.sessionRestored)
                    } else {
                        await send(.sessionCheckFailed)
                    }
                }

            case .emailChanged(let email):
                state.email = email
                return .none

            case .sendMagicLinkTapped:
                let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !email.isEmpty else {
                    state.errorMessage = "Please enter your email address."
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    try await authClient.signInWithOTP(email)
                    await send(.magicLinkSent)
                } catch: { error, send in
                    await send(.magicLinkFailed(error.localizedDescription))
                }

            case .magicLinkSent:
                state.isLoading = false
                state.step = .magicLinkSent
                return .none

            case .magicLinkFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .handleDeepLink(let url):
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    try await authClient.handleDeepLink(url)
                    await send(.sessionRestored)
                } catch: { error, send in
                    await send(.magicLinkFailed(error.localizedDescription))
                }

            case .sessionRestored:
                state.isLoading = false
                state.step = .authenticated
                return .none

            case .sessionCheckFailed:
                state.step = .landing
                return .none

            case .resendTapped:
                state.isLoading = true
                state.errorMessage = nil
                let email = state.email
                return .run { send in
                    try await authClient.signInWithOTP(email)
                    await send(.magicLinkSent)
                } catch: { error, send in
                    await send(.magicLinkFailed(error.localizedDescription))
                }

            case .useOtherEmailTapped:
                state.step = .landing
                state.email = ""
                state.errorMessage = nil
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
