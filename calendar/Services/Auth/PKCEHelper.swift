import Foundation
import CryptoKit

/// Utilities for the OAuth 2.0 PKCE (Proof Key for Code Exchange) flow.
///
/// - Note: PKCE prevents authorization code interception attacks by binding
///   the token exchange request to the original authorization request.
nonisolated enum PKCEHelper {
    /// Generates a cryptographically random code verifier (43-character base64url string).
    /// - Returns: A URL-safe base64-encoded random string.
    static func generateVerifier() -> String {
        generateRandomURLSafeString()
    }

    /// Generates a cryptographically random OAuth state value.
    /// - Returns: A URL-safe base64-encoded random string.
    static func generateState() -> String {
        generateRandomURLSafeString()
    }

    private static func generateRandomURLSafeString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Derives a SHA-256 code challenge from the given verifier.
    /// - Parameter verifier: The code verifier string.
    /// - Returns: A URL-safe base64-encoded SHA-256 hash of the verifier.
    static func generateChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
