import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        Form {
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
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")
                Link("Source Code", destination: URL(string: "https://github.com/rahilsinghi/MarkPush")!)
                Link("Report Issue", destination: URL(string: "https://github.com/rahilsinghi/MarkPush/issues")!)
            }
        }
        .navigationTitle("Settings")
        .onAppear { store.send(.onAppear) }
        .sheet(isPresented: $store.showPairing) {
            PairingView(
                store: Store(initialState: PairingFeature.State()) {
                    PairingFeature()
                }
            )
        }
    }
}
