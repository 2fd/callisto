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
    /// The custom URL scheme the OAuth redirect comes back on. Must match
    /// `CFBundleURLSchemes` in `Info.plist` — LaunchServices, not the app,
    /// decides who receives it. See ``AuthorizationSession``.
    static let callbackScheme: String = {
        clientId.split(separator: ".").reversed().joined(separator: ".")
    }()
    // MARK: - Scopes

    /// Reads the user's calendar list — names, colors, time zones, access roles.
    /// Deliberately *not* `calendar.readonly`: this is the narrowest scope that
    /// serves `GET /users/me/calendarList`, and it grants no access to event
    /// content at all.
    static let calendarListReadScope = "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
    /// Reads events on the calendars the user is subscribed to.
    static let eventsReadScope = "https://www.googleapis.com/auth/calendar.events.readonly"
    /// Reads *and writes* events. Requested separately from ``eventsReadScope``
    /// so Google's granular consent can offer a real read-only mode: declining
    /// this one leaves the app fully functional minus RSVP/delete.
    static let eventsWriteScope = "https://www.googleapis.com/auth/calendar.events"

    /// OAuth scopes requested during authorization.
    ///
    /// Each entry is the narrowest scope that serves an endpoint the app calls,
    /// which is what Google's sensitive-scope review asks for. The user may
    /// decline individual scopes; check ``OAuthTokens/canRead`` and
    /// ``OAuthTokens/canWrite`` for what was actually granted.
    static let scopes = [
        calendarListReadScope,
        eventsReadScope,
        eventsWriteScope,
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile",
    ]

    /// Broad Calendar scopes Callisto no longer requests.
    ///
    /// Accounts linked before the app narrowed its request still hold grants for
    /// these, and a refresh token keeps working until the user revokes it. They
    /// are recognized so an existing account does not silently degrade to
    /// "Calendar access needed" on upgrade — never added back to ``scopes``.
    static let legacyCalendarReadScope = "https://www.googleapis.com/auth/calendar.readonly"
    static let legacyCalendarFullScope = "https://www.googleapis.com/auth/calendar"
    private static let legacyCalendarListWriteScope = "https://www.googleapis.com/auth/calendar.calendarlist"

    /// Granted scopes that permit listing calendars.
    static let calendarListReadGrants: Set<String> = [
        calendarListReadScope,
        legacyCalendarListWriteScope,
        legacyCalendarReadScope,
        legacyCalendarFullScope,
    ]

    /// Granted scopes that permit reading events. `calendar.events` implies read
    /// access, and Google returns only the scope the user actually checked, so
    /// the write scope has to count here too.
    static let eventsReadGrants: Set<String> = [
        eventsReadScope,
        eventsWriteScope,
        legacyCalendarReadScope,
        legacyCalendarFullScope,
    ]

    /// Granted scopes that permit mutating events.
    static let eventsWriteGrants: Set<String> = [
        eventsWriteScope,
        legacyCalendarFullScope,
    ]

    /// Google OAuth authorization endpoint.
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    /// Google OAuth token exchange endpoint.
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
}
