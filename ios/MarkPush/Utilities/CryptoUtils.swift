import CommonCrypto
import CryptoKit
import Foundation

/// AES-256-GCM encryption/decryption matching the CLI's format.
///
/// Ciphertext format: nonce (12 bytes) || ciphertext || GCM tag (16 bytes),
/// then base64-standard-encoded. Must match the Go CLI implementation.
enum CryptoUtils {

    /// Decrypt a base64-encoded AES-256-GCM ciphertext.
    static func decrypt(encoded: String, key: Data) throws -> Data {
        guard let data = Data(base64Encoded: encoded) else {
            throw CryptoError.invalidBase64
        }

        let symmetricKey = SymmetricKey(data: key)
        let nonceSize = 12
        guard data.count >= nonceSize + 16 else { // nonce + minimum tag
            throw CryptoError.ciphertextTooShort
        }

        let nonce = try AES.GCM.Nonce(data: data.prefix(nonceSize))
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: data[nonceSize ..< (data.count - 16)],
            tag: data.suffix(16)
        )

        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    /// Encrypt plaintext with AES-256-GCM, returning base64-encoded output.
    static func encrypt(plaintext: Data, key: Data) throws -> String {
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)

        // Build nonce || ciphertext || tag format matching CLI.
        var combined = Data()
        combined.append(contentsOf: sealedBox.nonce)
        combined.append(sealedBox.ciphertext)
        combined.append(sealedBox.tag)

        return combined.base64EncodedString()
    }

    /// Derive a 32-byte key from a pairing secret using PBKDF2-SHA256.
    /// Parameters match the CLI: 100,000 iterations, 32-byte output.
    static func deriveKey(secret: String, salt: Data) throws -> Data {
        guard let secretData = secret.data(using: .utf8) else {
            throw CryptoError.invalidSecret
        }

        // Use CommonCrypto for PBKDF2 since CryptoKit doesn't expose it directly.
        var derivedKey = Data(count: 32)
        let status = derivedKey.withUnsafeMutableBytes { derivedBytes in
            secretData.withUnsafeBytes { secretBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        secretBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        secretData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100_000,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        return derivedKey
    }
}

enum CryptoError: LocalizedError {
    case invalidBase64
    case ciphertextTooShort
    case invalidSecret
    case keyDerivationFailed

    var errorDescription: String? {
        switch self {
        case .invalidBase64: "Invalid base64 encoded data"
        case .ciphertextTooShort: "Ciphertext is too short to contain nonce and tag"
        case .invalidSecret: "Invalid pairing secret"
        case .keyDerivationFailed: "Key derivation failed"
        }
    }
}
