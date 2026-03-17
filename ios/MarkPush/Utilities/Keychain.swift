import Foundation
@preconcurrency import KeychainAccess

/// Manages secure storage of encryption keys and device secrets.
enum KeychainManager: Sendable {
    // nonisolated(unsafe) silences the Sendable warning for KeychainAccess
    // which doesn't yet conform to Sendable but is safe for our static usage.
    nonisolated(unsafe) private static let keychain = Keychain(service: "com.markpush.app")
        .accessibility(.afterFirstUnlock)

    /// Store the shared encryption key for a paired device.
    static func saveEncryptionKey(_ key: Data, for deviceID: String) throws {
        try keychain.set(key, key: "encryption-key-\(deviceID)")
    }

    /// Retrieve the encryption key for a paired device.
    static func loadEncryptionKey(for deviceID: String) throws -> Data? {
        try keychain.getData("encryption-key-\(deviceID)")
    }

    /// Remove the encryption key for an unpaired device.
    static func removeEncryptionKey(for deviceID: String) throws {
        try keychain.remove("encryption-key-\(deviceID)")
    }

    /// Store this device's unique ID.
    static func saveDeviceID(_ id: String) throws {
        try keychain.set(id, key: "device-id")
    }

    /// Retrieve this device's unique ID, generating one if needed.
    static func loadOrCreateDeviceID() throws -> String {
        if let existing = try keychain.getString("device-id") {
            return existing
        }
        let newID = UUID().uuidString
        try saveDeviceID(newID)
        return newID
    }
}
