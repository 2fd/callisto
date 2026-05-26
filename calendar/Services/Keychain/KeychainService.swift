import Foundation
import os
import Security

/// Wrapper around the macOS Keychain for securely storing ``OAuthTokens``.
///
/// All tokens are stored as `kSecClassGenericPassword` items keyed by the
/// app's bundle identifier (service) and the Google account ID (account).
///
/// - Important: This is the **only** approved storage location for OAuth tokens.
nonisolated enum KeychainService {
    private static let service = Bundle.main.bundleIdentifier ?? Constants.subsystem

    private static func query(for accountId: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountId,
        ]

        // The Data Protection keychain requires the signed app's access-group entitlement.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        query[kSecUseDataProtectionKeychain as String] = true

        return query
    }

    /// Saves tokens to the Keychain. Automatically updates if an entry already exists.
    /// - Parameters:
    ///   - tokens: The OAuth tokens to store.
    ///   - accountId: The Google account ID used as the Keychain account key.
    /// - Throws: ``KeychainError`` if the operation fails.
    static func save(tokens: OAuthTokens, for accountId: String) throws {
        guard let data = try? JSONEncoder().encode(tokens) else {
            throw KeychainError.encodingFailed
        }

        var query = query(for: accountId)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            Logger.shared.debug("Keychain item exists for account \(accountId, privacy: .public), updating")
            try update(tokens: tokens, for: accountId)
        } else if status != errSecSuccess {
            Logger.shared.error("Keychain save failed for account \(accountId, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unexpectedStatus(status)
        } else {
            Logger.shared.debug("Keychain save succeeded for account \(accountId, privacy: .public)")
        }
    }

    /// Loads tokens from the Keychain for the given account.
    /// - Parameter accountId: The Google account ID.
    /// - Returns: The stored ``OAuthTokens``.
    /// - Throws: ``KeychainError/itemNotFound`` if no entry exists, or another ``KeychainError``.
    static func load(for accountId: String) throws -> OAuthTokens {
        var query = query(for: accountId)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                Logger.shared.debug("Keychain item not found for account \(accountId, privacy: .public)")
                throw KeychainError.itemNotFound
            }
            Logger.shared.error("Keychain load failed for account \(accountId, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }

        guard let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else {
            Logger.shared.error("Keychain data decoding failed for account \(accountId, privacy: .public)")
            throw KeychainError.decodingFailed
        }

        Logger.shared.debug("Keychain load succeeded for account \(accountId, privacy: .public)")
        return tokens
    }

    /// Updates an existing Keychain entry with new tokens.
    /// - Parameters:
    ///   - tokens: The new OAuth tokens.
    ///   - accountId: The Google account ID.
    /// - Throws: ``KeychainError/itemNotFound`` if no entry exists to update.
    private static func update(tokens: OAuthTokens, for accountId: String) throws {
        guard let data = try? JSONEncoder().encode(tokens) else {
            throw KeychainError.encodingFailed
        }

        let query = query(for: accountId)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            Logger.shared.error("Keychain update failed: item not found for account \(accountId, privacy: .public)")
            throw KeychainError.itemNotFound
        } else if status != errSecSuccess {
            Logger.shared.error("Keychain update failed for account \(accountId, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Deletes the Keychain entry for the given account.
    ///
    /// Does not throw if the item was already absent.
    /// - Parameter accountId: The Google account ID.
    /// - Throws: ``KeychainError`` if the deletion fails for an unexpected reason.
    static func delete(for accountId: String) throws {
        let query = query(for: accountId)

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.shared.error("Keychain delete failed for account \(accountId, privacy: .public), OSStatus: \(status)")
            throw KeychainError.unexpectedStatus(status)
        } else {
            Logger.shared.debug("Keychain delete succeeded for account \(accountId, privacy: .public)")
        }
    }
}
