import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
            Section("Account") {
                if let email = store.userEmail {
                    LabeledContent("Email", value: email)
                }
                Button(role: .destructive) {
                    store.send(.signOutTapped)
                } label: {
                    if store.isSigningOut {
                        ProgressView()
                    } else {
                        Text("Sign Out")
                    }
                }
                .disabled(store.isSigningOut)
            }

            Section("Devices") {
                if store.hasPairedDevice {
                    Label("Paired", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button("Pair New Device") {
                    store.send(.showPairingTapped)
                }
            }

            Section("Reader") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(store.readerFontSize))pt")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { store.readerFontSize },
                        set: { store.send(.setFontSize($0)) }
                    ),
                    in: 12...28,
                    step: 1
                )
            }

            Section("About") {
                LabeledContent("Version", value: {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
                    return "\(version) (\(build))"
                }())
                Link("Source Code", destination: URL(string: "https://github.com/rahilsinghi/MarkPush")!)
                Link("Report Issue", destination: URL(string: "https://github.com/rahilsinghi/MarkPush/issues")!)
            }
        }
        .navigationTitle("Settings")
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: Binding(
            get: { store.showPairing },
            set: { newValue in
                if !newValue { store.send(.dismissPairing) }
            }
        )) {
            PairingView(
                store: Store(initialState: PairingFeature.State()) {
                    PairingFeature()
                }
            )
        }
    }
}
