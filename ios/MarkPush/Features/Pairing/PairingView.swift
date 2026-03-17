import CodeScanner
import ComposableArchitecture
import SwiftUI

struct PairingView: View {
    @Bindable var store: StoreOf<PairingFeature>

    var body: some View {
        NavigationStack {
            Group {
                switch store.step {
                case .instructions:
                    instructionsView
                case .scanning:
                    scannerView
                case .pairing:
                    pairingView
                case .success:
                    successView
                case .error:
                    errorView
                }
            }
            .navigationTitle("Pair Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.dismiss) }
                }
            }
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Pair with your computer")
                    .font(.title2.bold())

                Text("Open your terminal and run:")
                    .foregroundStyle(.secondary)

                Text("markpush pair")
                    .font(.system(.title3, design: .monospaced))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))

                Text("Then scan the QR code that appears.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.send(.startScanning)
            } label: {
                Text("Scan QR Code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var scannerView: some View {
        CodeScannerView(
            codeTypes: [.qr],
            showViewfinder: true
        ) { result in
            switch result {
            case .success(let scan):
                store.send(.qrCodeScanned(scan.string))
            case .failure(let error):
                store.send(.pairingFailed(error.localizedDescription))
            }
        }
        .ignoresSafeArea()
    }

    private var pairingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Pairing...")
                .font(.title3)
            Text("Establishing secure connection")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Paired!")
                .font(.title.bold())

            if let name = store.pairedDeviceName {
                Text("Connected to \(name)")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") { store.send(.dismiss) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Pairing Failed")
                .font(.title2.bold())

            if let error = store.errorMessage {
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button("Try Again") { store.send(.startScanning) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }
}
