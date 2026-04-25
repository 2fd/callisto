import Foundation

/// Configuration constants for Google OAuth 2.0 authentication.
///
/// The ``clientId`` is read from the app's `Info.plist` (populated by `Config.xcconfig`).
/// All other values are derived or hard-coded Google endpoint URLs.
nonisolated enum AuthConfig {
    /// Google OAuth client ID, read from `GOOGLE_CLIENT_ID` in `Info.plist`.
    static let clientId: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String, !id.isEmpty else {
            fatalError("GOOGLE_CLIENT_ID not set. Add it to Config.xcconfig.")
        }
        return id
    }()
    /// Custom URL scheme redirect URI derived from the reversed client ID.
    static let redirectURI: String = {
        let reversed = clientId.split(separator: ".").reversed().joined(separator: ".")
        return "\(reversed):/oauthredirect"
    }()
    /// The custom URL scheme used by `ASWebAuthenticationSession` to capture the OAuth callback.
    static let callbackScheme: String = {
        clientId.split(separator: ".").reversed().joined(separator: ".")
    }()
    /// OAuth scopes requested during authorization.
    ///
    /// Includes `calendar.events` for read+write access to events (accept/reject/edit).
    /// The user may decline individual scopes; check ``OAuthTokens/hasEventsWriteScope``
    /// to determine what was actually granted.
    static let scopes = [
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/calendar.events",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ]

    /// The scope URI that grants read+write access to calendar events.
    static let eventsWriteScope = "https://www.googleapis.com/auth/calendar.events"

    /// Google OAuth authorization endpoint.
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    /// Google OAuth token exchange endpoint.
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}
