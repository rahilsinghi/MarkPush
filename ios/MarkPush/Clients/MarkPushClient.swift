import ComposableArchitecture
import Foundation
import os
import UIKit

private let logger = Logger(subsystem: "com.rahilsinghi.markpush", category: "Client")

/// TCA dependency for MarkPush operations.
struct MarkPushClient {
    /// Start receiving messages (from WiFi or cloud).
    var startReceiving: @Sendable () async -> AsyncStream<PushMessage>
    /// Stop receiving.
    var stopReceiving: @Sendable () async -> Void
    /// Decrypt message content if encrypted.
    var decryptContent: @Sendable (PushMessage) async throws -> String
    /// Complete pairing with a scanned QR payload.
    var completePairing: @Sendable (PairInitPayload) async throws -> String // returns device name
    /// Check if we have a paired device.
    var hasPairedDevice: @Sendable () async -> Bool
}

/// Keeps receivers alive for the duration of the receiving session.
private nonisolated(unsafe) var activeWiFiReceiver: WiFiReceiver?
private nonisolated(unsafe) var activeCloudReceiver: CloudReceiver?

extension MarkPushClient: DependencyKey {
    static let liveValue = MarkPushClient(
        startReceiving: {
            // Stop any existing receivers before starting new ones.
            if let wifi = activeWiFiReceiver {
                await wifi.stop()
                activeWiFiReceiver = nil
            }
            if let cloud = activeCloudReceiver {
                await cloud.stop()
                activeCloudReceiver = nil
            }

            let deviceID = (try? KeychainManager.loadOrCreateDeviceID()) ?? UUID().uuidString

            // Start WiFi receiver.
            let wifiReceiver = WiFiReceiver(deviceID: deviceID)
            try? await wifiReceiver.start()
            activeWiFiReceiver = wifiReceiver

            // Start Cloud receiver if user is authenticated.
            // Use lowercased UUID to match CLI/MCP convention.
            do {
                let session = try await AuthClient.supabase.auth.session
                let userID = session.user.id.uuidString.lowercased()
                logger.info("Cloud: authenticated as \(userID, privacy: .public)")

                let cloudReceiver = CloudReceiver(
                    client: AuthClient.supabase,
                    userID: userID
                )
                activeCloudReceiver = cloudReceiver
                // Start cloud in background — don't block WiFi.
                Task {
                    do {
                        try await cloudReceiver.start()
                    } catch {
                        logger.error("Cloud: receiver failed — \(error.localizedDescription, privacy: .public)")
                    }
                }
            } catch {
                logger.warning("Cloud: no auth session — \(error.localizedDescription, privacy: .public). Cloud receiver disabled.")
            }

            // Merge WiFi and Cloud streams into one.
            return AsyncStream { continuation in
                // Forward WiFi messages.
                Task {
                    for await msg in wifiReceiver.messages {
                        continuation.yield(msg)
                    }
                }
                // Forward Cloud messages.
                if let cloudReceiver = activeCloudReceiver {
                    Task {
                        for await msg in cloudReceiver.messages {
                            continuation.yield(msg)
                        }
                    }
                }
            }
        },
        stopReceiving: {
            if let wifi = activeWiFiReceiver {
                await wifi.stop()
                activeWiFiReceiver = nil
            }
            if let cloud = activeCloudReceiver {
                await cloud.stop()
                activeCloudReceiver = nil
            }
        },
        decryptContent: { message in
            guard message.encrypted else {
                guard let data = Data(base64Encoded: message.content),
                      let text = String(data: data, encoding: .utf8) else {
                    return message.content
                }
                return text
            }

            let deviceID = try KeychainManager.loadOrCreateDeviceID()
            guard let key = try KeychainManager.loadEncryptionKey(for: message.senderID) else {
                throw MarkPushError.noEncryptionKey
            }

            let decrypted = try CryptoUtils.decrypt(encoded: message.content, key: key)
            guard let text = String(data: decrypted, encoding: .utf8) else {
                throw MarkPushError.invalidContent
            }
            return text
        },
        completePairing: { payload in
            let deviceID = try KeychainManager.loadOrCreateDeviceID()

            // Derive shared key.
            guard let salt = deviceID.data(using: .utf8) else {
                throw MarkPushError.invalidDeviceID
            }
            let key = try CryptoUtils.deriveKey(secret: payload.secret, salt: salt)

            // Store key in Keychain.
            try KeychainManager.saveEncryptionKey(key, for: payload.senderID)

            // Notify the CLI that pairing is complete.
            let url = URL(string: "http://\(payload.host):\(payload.port)/pair")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let deviceName = await UIDevice.current.name
            let body = [
                "device_id": deviceID,
                "device_name": deviceName,
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw MarkPushError.pairingFailed
            }

            return payload.senderName
        },
        hasPairedDevice: {
            // Check if any encryption keys exist.
            let deviceID = (try? KeychainManager.loadOrCreateDeviceID()) ?? ""
            return (try? KeychainManager.loadEncryptionKey(for: deviceID)) != nil
        }
    )

    static let testValue = MarkPushClient(
        startReceiving: { AsyncStream { _ in } },
        stopReceiving: {},
        decryptContent: { _ in "# Test Content" },
        completePairing: { _ in "Test Device" },
        hasPairedDevice: { false }
    )
}

extension DependencyValues {
    var markPushClient: MarkPushClient {
        get { self[MarkPushClient.self] }
        set { self[MarkPushClient.self] = newValue }
    }
}

enum MarkPushError: LocalizedError {
    case noEncryptionKey
    case invalidContent
    case invalidDeviceID
    case pairingFailed

    var errorDescription: String? {
        switch self {
        case .noEncryptionKey: "No encryption key found for this sender"
        case .invalidContent: "Could not decode message content"
        case .invalidDeviceID: "Invalid device ID"
        case .pairingFailed: "Pairing handshake failed"
        }
    }
}
