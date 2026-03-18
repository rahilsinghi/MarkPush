import ComposableArchitecture
import Foundation
import Supabase

/// Lightweight representation of an authenticated session.
struct AuthSession: Equatable, Sendable {
    let userId: String
    let email: String
}

/// TCA dependency for Supabase authentication.
struct AuthClient: Sendable {
    /// Send a magic-link OTP email.
    var signInWithOTP: @Sendable (String) async throws -> Void
    /// Verify a 6-digit OTP code from the email.
    var verifyOTP: @Sendable (_ email: String, _ token: String) async throws -> Void
    /// Exchange the deep-link callback URL for a session.
    var handleDeepLink: @Sendable (URL) async throws -> Void
    /// Return the current session if one is persisted, or nil.
    var restoreSession: @Sendable () async -> AuthSession?
    /// Sign the current user out.
    var signOut: @Sendable () async throws -> Void
    /// The authenticated user's email, if any.
    var currentUserEmail: @Sendable () async -> String?
    /// Check if the current authenticated user is on the beta whitelist.
    var isWhitelisted: @Sendable () async throws -> Bool
}

// MARK: - Live Implementation

extension AuthClient: DependencyKey {
    /// Shared Supabase client — reads URL and anon key from Info.plist.
    /// Internal access so CloudReceiver can reuse the authenticated session.
    static let supabase: SupabaseClient = {
        guard let urlString = Bundle.main.infoDictionary?["SupabaseURL"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString),
              let key = Bundle.main.infoDictionary?["SupabaseAnonKey"] as? String,
              !key.isEmpty else {
            fatalError(
                "Missing SupabaseURL or SupabaseAnonKey in Info.plist. "
                + "Add your Supabase project credentials to ios/MarkPush/Info.plist."
            )
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }()

    private static let redirectURL = URL(string: "markpush://auth/callback")

    static let liveValue = AuthClient(
        signInWithOTP: { email in
            try await supabase.auth.signInWithOTP(
                email: email,
                redirectTo: redirectURL
            )
        },
        verifyOTP: { email, token in
            _ = try await supabase.auth.verifyOTP(
                email: email,
                token: token,
                type: .magiclink
            )
        },
        handleDeepLink: { url in
            _ = try await supabase.auth.session(from: url)
        },
        restoreSession: {
            guard let session = try? await supabase.auth.session else { return nil }
            return AuthSession(
                userId: session.user.id.uuidString,
                email: session.user.email ?? ""
            )
        },
        signOut: {
            try await supabase.auth.signOut()
        },
        currentUserEmail: {
            try? await supabase.auth.session.user.email
        },
        isWhitelisted: {
            struct Row: Decodable { let id: String }
            let rows: [Row] = try await supabase
                .from("beta_whitelist")
                .select("id")
                .execute()
                .value
            return !rows.isEmpty
        }
    )

    static let testValue = AuthClient(
        signInWithOTP: { _ in },
        verifyOTP: { _, _ in },
        handleDeepLink: { _ in },
        restoreSession: { nil },
        signOut: {},
        currentUserEmail: { nil },
        isWhitelisted: { true }
    )

    static let previewValue = AuthClient(
        signInWithOTP: { _ in },
        verifyOTP: { _, _ in },
        handleDeepLink: { _ in },
        restoreSession: { nil },
        signOut: {},
        currentUserEmail: { "preview@example.com" },
        isWhitelisted: { true }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
