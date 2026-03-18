import ComposableArchitecture
import Foundation

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var step: Step = .checking
        var email: String = ""
        var otpCode: String = ""
        var isLoading: Bool = false
        var errorMessage: String?

        enum Step: Equatable {
            case checking
            case landing
            case magicLinkSent
            case enteringCode
            case authenticated
            case notWhitelisted
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
        // OTP code entry
        case enterCodeTapped
        case otpCodeChanged(String)
        case verifyCodeTapped
        case backToMagicLinkTapped
        // Whitelist
        case notWhitelisted
        case tryOtherEmailTapped
    }

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.step == .checking else { return .none }
                return .run { send in
                    if let _ = await authClient.restoreSession() {
                        // Check if session is older than 30 days — force re-auth if so.
                        let lastAuth = UserDefaults.standard.object(forKey: "lastAuthDate") as? Date
                        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
                        if let lastAuth, lastAuth < thirtyDaysAgo {
                            try? await authClient.signOut()
                            await send(.sessionCheckFailed)
                        } else {
                            await send(.sessionRestored)
                        }
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
                    let whitelisted = (try? await authClient.isWhitelisted()) ?? true
                    if whitelisted {
                        await send(.sessionRestored)
                    } else {
                        try? await authClient.signOut()
                        await send(.notWhitelisted)
                    }
                } catch: { error, send in
                    await send(.magicLinkFailed(error.localizedDescription))
                }

            case .sessionRestored:
                state.isLoading = false
                state.step = .authenticated
                UserDefaults.standard.set(Date.now, forKey: "lastAuthDate")
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

            // MARK: - OTP Code Entry

            case .enterCodeTapped:
                state.step = .enteringCode
                state.otpCode = ""
                state.errorMessage = nil
                return .none

            case .otpCodeChanged(let code):
                // Only allow digits, max 8 characters (Supabase OTP is configurable: 4–8)
                let filtered = String(code.filter(\.isNumber).prefix(8))
                state.otpCode = filtered
                return .none

            case .verifyCodeTapped:
                let code = state.otpCode
                guard code.count >= 4 else {
                    state.errorMessage = "Please enter the code from your email."
                    return .none
                }
                state.isLoading = true
                state.errorMessage = nil
                let email = state.email
                return .run { send in
                    try await authClient.verifyOTP(email, code)
                    let whitelisted = (try? await authClient.isWhitelisted()) ?? true
                    if whitelisted {
                        await send(.sessionRestored)
                    } else {
                        try? await authClient.signOut()
                        await send(.notWhitelisted)
                    }
                } catch: { error, send in
                    await send(.magicLinkFailed(error.localizedDescription))
                }

            case .backToMagicLinkTapped:
                state.step = .magicLinkSent
                state.otpCode = ""
                state.errorMessage = nil
                return .none

            // MARK: - Whitelist

            case .notWhitelisted:
                state.isLoading = false
                state.step = .notWhitelisted
                return .none

            case .tryOtherEmailTapped:
                state.step = .landing
                state.email = ""
                state.otpCode = ""
                state.errorMessage = nil
                return .none
            }
        }
    }
}
