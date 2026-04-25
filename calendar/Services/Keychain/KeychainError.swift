import Foundation

/// Errors that can occur during Keychain operations.
nonisolated enum KeychainError: LocalizedError, Sendable {
    /// No item was found for the given key.
    case itemNotFound
    /// An unexpected Security framework status code.
    case unexpectedStatus(OSStatus)
    /// The token data could not be encoded to JSON.
    case encodingFailed
    /// The stored Keychain data could not be decoded from JSON.
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            "No item found in the Keychain for this key."
        case .unexpectedStatus(let status):
            "Keychain error: \(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error (\(status))")"
        case .encodingFailed:
            "Failed to encode data for Keychain storage."
        case .decodingFailed:
            "Failed to decode data from Keychain."
        }
    }
}
