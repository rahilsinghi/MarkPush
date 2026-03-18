import ComposableArchitecture
import SwiftUI

// MARK: - Auth View (container)

struct AuthView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        ZStack {
            Color.mpBackground.ignoresSafeArea()

            switch store.step {
            case .checking:
                ProgressView()
                    .tint(.mpAccent)

            case .landing:
                AuthLandingView(store: store)

            case .magicLinkSent:
                MagicLinkSentView(store: store)

            case .enteringCode:
                OTPCodeEntryView(store: store)

            case .notWhitelisted:
                NotWhitelistedView(store: store)

            case .authenticated:
                EmptyView()
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - Landing View

private struct AuthLandingView: View {
    @Bindable var store: StoreOf<AuthFeature>
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        VStack(spacing: MPSpacing.xxl) {
            Spacer()

            // Logo & tagline
            VStack(spacing: MPSpacing.md) {
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mpAccent)
                    .accessibilityHidden(true)

                Text("MarkPush")
                    .font(MPFont.appTitle)
                    .foregroundStyle(Color.mpTextPrimary)

                Text("Your AI's work,\nbeautifully on your phone")
                    .font(MPFont.body)
                    .foregroundStyle(Color.mpTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Email input + CTA
            VStack(spacing: MPSpacing.lg) {
                TextField("Email address", text: $store.email.sending(\.emailChanged))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(MPFont.body)
                    .padding(MPSpacing.lg)
                    .background(Color.mpSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: MPSpacing.buttonRadius)
                            .strokeBorder(Color.mpAccent.opacity(isEmailFocused ? 0.5 : 0.15), lineWidth: 1)
                    )
                    .focused($isEmailFocused)
                    .submitLabel(.go)
                    .onSubmit { store.send(.sendMagicLinkTapped) }
                    .accessibilityLabel("Email address")

                Button {
                    store.send(.sendMagicLinkTapped)
                } label: {
                    Group {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue with Email")
                                .font(MPFont.bodyMedium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(MPSpacing.lg)
                    .background(Color.mpAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                }
                .disabled(store.isLoading || store.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(store.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .accessibilityLabel("Continue with email")

                Text("We'll send you a sign-in code")
                    .font(MPFont.metadata)
                    .foregroundStyle(Color.mpTextTertiary)
            }

            // Error message
            if let error = store.errorMessage {
                Text(error)
                    .font(MPFont.metadata)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            Spacer()
                .frame(height: MPSpacing.section)
        }
        .padding(.horizontal, MPSpacing.screenPadding)
        .animation(.easeInOut(duration: 0.2), value: store.errorMessage)
    }
}

// MARK: - Magic Link Sent View

private struct MagicLinkSentView: View {
    let store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: MPSpacing.xxl) {
            Spacer()

            VStack(spacing: MPSpacing.lg) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mpAccent)
                    .accessibilityHidden(true)

                Text("Check your email")
                    .font(MPFont.readerH1)
                    .foregroundStyle(Color.mpTextPrimary)

                Text("We sent a sign-in link and code to")
                    .font(MPFont.body)
                    .foregroundStyle(Color.mpTextSecondary)

                Text(store.email)
                    .font(MPFont.bodyMedium)
                    .foregroundStyle(Color.mpTextPrimary)
            }

            Spacer()

            VStack(spacing: MPSpacing.lg) {
                // Enter code — primary action (works everywhere including simulator)
                Button {
                    store.send(.enterCodeTapped)
                } label: {
                    Text("Enter Code")
                        .font(MPFont.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(MPSpacing.lg)
                        .background(Color.mpAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                }
                .accessibilityLabel("Enter sign-in code from email")

                // Open Mail — secondary, only shown when Mail app is available
                if let mailURL = URL(string: "message://"),
                   UIApplication.shared.canOpenURL(mailURL) {
                    Link(destination: mailURL) {
                        Text("Open Mail App")
                            .font(MPFont.bodyMedium)
                            .frame(maxWidth: .infinity)
                            .padding(MPSpacing.lg)
                            .background(Color.mpSurface)
                            .foregroundStyle(Color.mpAccent)
                            .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: MPSpacing.buttonRadius)
                                    .strokeBorder(Color.mpAccent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Open Mail app")
                }

                // Resend / use other email
                HStack(spacing: MPSpacing.lg) {
                    Button {
                        store.send(.resendTapped)
                    } label: {
                        if store.isLoading {
                            ProgressView()
                                .tint(.mpAccent)
                        } else {
                            Text("Resend link")
                                .font(MPFont.metadata)
                                .foregroundStyle(Color.mpAccent)
                        }
                    }
                    .disabled(store.isLoading)
                    .accessibilityLabel("Resend magic link")

                    Text("\u{00B7}")
                        .foregroundStyle(Color.mpTextTertiary)

                    Button {
                        store.send(.useOtherEmailTapped)
                    } label: {
                        Text("Use other email")
                            .font(MPFont.metadata)
                            .foregroundStyle(Color.mpAccent)
                    }
                    .accessibilityLabel("Use a different email address")
                }

                // Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(MPFont.metadata)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }

            Spacer()
                .frame(height: MPSpacing.section)
        }
        .padding(.horizontal, MPSpacing.screenPadding)
        .animation(.easeInOut(duration: 0.2), value: store.errorMessage)
    }
}

// MARK: - OTP Code Entry View

private struct OTPCodeEntryView: View {
    @Bindable var store: StoreOf<AuthFeature>
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: MPSpacing.xxl) {
            Spacer()

            VStack(spacing: MPSpacing.lg) {
                Image(systemName: "number.square.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mpAccent)
                    .accessibilityHidden(true)

                Text("Enter your code")
                    .font(MPFont.readerH1)
                    .foregroundStyle(Color.mpTextPrimary)

                Text("Enter the code from your email")
                    .font(MPFont.body)
                    .foregroundStyle(Color.mpTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // Code input
            TextField("000000", text: $store.otpCode.sending(\.otpCodeChanged))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(MPSpacing.lg)
                .background(Color.mpSurface)
                .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: MPSpacing.buttonRadius)
                        .strokeBorder(Color.mpAccent.opacity(isCodeFocused ? 0.5 : 0.15), lineWidth: 1)
                )
                .focused($isCodeFocused)
                .accessibilityLabel("Sign-in code")
                .onAppear { isCodeFocused = true }

            Spacer()

            VStack(spacing: MPSpacing.lg) {
                // Verify button
                Button {
                    store.send(.verifyCodeTapped)
                } label: {
                    Group {
                        if store.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Verify Code")
                                .font(MPFont.bodyMedium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(MPSpacing.lg)
                    .background(Color.mpAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                }
                .disabled(store.isLoading || store.otpCode.count < 6)
                .opacity(store.otpCode.count < 6 ? 0.5 : 1)
                .accessibilityLabel("Verify sign-in code")

                // Back to magic link
                Button {
                    store.send(.backToMagicLinkTapped)
                } label: {
                    Text("Back to magic link")
                        .font(MPFont.metadata)
                        .foregroundStyle(Color.mpAccent)
                }
                .accessibilityLabel("Go back to magic link screen")

                // Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(MPFont.metadata)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }
            }

            Spacer()
                .frame(height: MPSpacing.section)
        }
        .padding(.horizontal, MPSpacing.screenPadding)
        .animation(.easeInOut(duration: 0.2), value: store.errorMessage)
    }
}

// MARK: - Not Whitelisted View

private struct NotWhitelistedView: View {
    let store: StoreOf<AuthFeature>

    var body: some View {
        VStack(spacing: MPSpacing.xxl) {
            Spacer()

            VStack(spacing: MPSpacing.lg) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.mpTextTertiary)
                    .accessibilityHidden(true)

                Text("Beta access required")
                    .font(MPFont.readerH1)
                    .foregroundStyle(Color.mpTextPrimary)

                Text("MarkPush is in closed beta.\nYour account isn't on the invite list yet.")
                    .font(MPFont.body)
                    .foregroundStyle(Color.mpTextSecondary)
                    .multilineTextAlignment(.center)

                Text(store.email)
                    .font(MPFont.bodyMedium)
                    .foregroundStyle(Color.mpTextPrimary)
            }

            Spacer()

            VStack(spacing: MPSpacing.lg) {
                Button {
                    store.send(.tryOtherEmailTapped)
                } label: {
                    Text("Try another email")
                        .font(MPFont.bodyMedium)
                        .frame(maxWidth: .infinity)
                        .padding(MPSpacing.lg)
                        .background(Color.mpAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: MPSpacing.buttonRadius))
                }
                .accessibilityLabel("Try signing in with a different email")
            }

            Spacer()
                .frame(height: MPSpacing.section)
        }
        .padding(.horizontal, MPSpacing.screenPadding)
    }
}
