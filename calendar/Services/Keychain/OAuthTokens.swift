import Foundation

/// OAuth 2.0 access and refresh tokens for a Google account.
///
/// Persisted as JSON in the macOS Keychain via ``KeychainService``.
///
/// - Important: Never store these tokens in SwiftData or UserDefaults.
nonisolated struct OAuthTokens: Codable, Sendable {
    /// Short-lived token used to authorize Google API requests.
    var accessToken: String
    /// Long-lived token used to obtain new access tokens.
    var refreshToken: String
    /// When the ``accessToken`` expires.
    var expiresAt: Date
    /// OAuth scopes actually granted by the user during consent.
    ///
    /// Defaults to an empty array for backward compatibility with tokens
    /// stored before this field was introduced.
    var grantedScopes: [String]

    /// Whether the access token is expired or will expire within 60 seconds.
    var isExpired: Bool {
        Date.now.addingTimeInterval(60) >= expiresAt
    }

    /// Whether the granted scopes allow listing the account's calendars.
    var canListCalendars: Bool {
        grants(AuthConfig.calendarListReadGrants)
    }

    /// Whether the granted scopes allow reading events.
    var canReadEvents: Bool {
        grants(AuthConfig.eventsReadGrants)
    }

    /// Whether the account can sync at all.
    ///
    /// Syncing needs both halves: the calendar list names what to fetch, and the
    /// event scope fetches it. Either one alone produces an account that appears
    /// connected but shows nothing, so both are required before the UI treats
    /// the account as readable.
    var canRead: Bool {
        canListCalendars && canReadEvents
    }

    /// Whether the granted scopes include event write access (`calendar.events`).
    var canWrite: Bool {
        grants(AuthConfig.eventsWriteGrants)
    }

    private func grants(_ accepted: Set<String>) -> Bool {
        grantedScopes.contains(where: accepted.contains)
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date, grantedScopes: [String] = []) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.grantedScopes = grantedScopes
    }

    // MARK: - Token Response Decoding

    /// Creates tokens by decoding a JSON response from Google's token endpoint.
    ///
    /// Falls back to the provided refresh token and scopes when the response
    /// omits them (e.g. during a token refresh, Google does not re-issue the
    /// refresh token).
    ///
    /// - Parameters:
    ///   - data: Raw JSON response data from the token endpoint.
    ///   - fallbackRefreshToken: Used when the response omits `refresh_token`.
    ///   - fallbackScopes: Used when the response omits `scope`.
    /// - Throws: ``AuthError/tokenExchangeFailed(_:)`` if required fields are missing.
    init(fromTokenResponse data: Data, fallbackRefreshToken: String? = nil, fallbackScopes: [String]? = nil) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int else {
            throw AuthError.tokenExchangeFailed("Invalid token response")
        }

        let refreshToken = (json["refresh_token"] as? String) ?? fallbackRefreshToken ?? ""
        let grantedScopes: [String] = {
            if let scopeString = json["scope"] as? String {
                return scopeString.split(separator: " ").map(String.init)
            }
            return fallbackScopes ?? []
        }()

        self.init(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date.now.addingTimeInterval(TimeInterval(expiresIn)),
            grantedScopes: grantedScopes
        )
    }

    // MARK: - Codable (backward-compatible)

    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, expiresAt, grantedScopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        grantedScopes = (try? container.decode([String].self, forKey: .grantedScopes)) ?? []
    }
}
