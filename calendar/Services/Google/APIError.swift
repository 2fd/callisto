import Foundation

/// A typed classification of a Google API failure.
///
/// The status code alone is never enough to decide what to do: the Calendar API
/// returns **403 for both** "your token lacks the scope" (`insufficientPermissions`,
/// permanent, needs the user) and "you are going too fast" (`rateLimitExceeded`,
/// `userRateLimitExceeded`, `quotaExceeded`, transient, needs backoff). Classifying
/// on the code alone therefore treats ordinary throttling as a revoked grant.
///
/// Every case below maps to a row of Google's documented error table, and the
/// `isRetryable` / `requiresUserAction` / `requiresFullSync` properties encode the
/// action that table prescribes.
///
/// Reference: https://developers.google.com/workspace/calendar/api/guides/errors
nonisolated enum APIError: LocalizedError, Sendable, Equatable {

    /// 400 — the request itself is malformed. Never retry; this is a client bug.
    /// Also returned when a disallowed query parameter is combined with `syncToken`.
    case invalidRequest(reason: String, message: String)

    /// 401 `authError` — the access token is missing, expired or invalid.
    /// Google's prescribed action is to obtain a new access token from the refresh
    /// token and retry; only a failing refresh means the user must re-consent.
    case needsReauth(message: String)

    /// 403 `insufficientPermissions` / `ACCESS_TOKEN_SCOPE_INSUFFICIENT` — the
    /// identity is known but the token does not carry the required scope.
    /// Permanent until the user re-authorizes. **Not** a reason to drop cached data.
    case scopeDenied(reason: String, message: String)

    /// 403 for a non-scope, non-quota reason (e.g. `forbiddenForNonOrganizer`).
    /// The request is not permitted as formed; retrying it unchanged will not help.
    case forbidden(reason: String, message: String)

    /// 403 in the `usageLimits` domain, or 429 — transient throttling.
    /// Retry with truncated exponential backoff.
    case throttled(reason: String, retryAfter: TimeInterval?)

    /// 404 `notFound` — Google documents exponential backoff for this, so it is
    /// treated as transient and is **not** taken as proof the resource is gone.
    case notFound(message: String)

    /// 409 — `duplicate` or `conflict` on a write.
    case conflict(reason: String, message: String)

    /// 410 `fullSyncRequired` / `updatedMinTooLongAgo` — the incremental cursor is
    /// no longer usable. Discard the cursor and re-fetch the full window.
    case fullSyncRequired(reason: String)

    /// 410 `deleted` — the resource is genuinely gone. The only authoritative
    /// "this no longer exists" signal the API gives us.
    case resourceDeleted

    /// 412 `conditionNotMet` — a precondition (ETag) failed; re-fetch and re-apply.
    case preconditionFailed(message: String)

    /// 5xx — server-side failure. Retry with backoff.
    case server(statusCode: Int, message: String)

    /// The request never produced an HTTP response (offline, DNS, timeout).
    case transport(String)

    /// A non-2xx status we have no specific rule for.
    case unexpected(statusCode: Int, body: String)

    // MARK: - Dispositions

    /// Whether retrying the identical request may succeed.
    var isRetryable: Bool {
        switch self {
        case .throttled, .server, .transport, .notFound: true
        case .invalidRequest, .needsReauth, .scopeDenied, .forbidden, .conflict,
            .fullSyncRequired, .resourceDeleted, .preconditionFailed, .unexpected:
            false
        }
    }

    /// Whether clearing this requires the user to re-run the consent flow.
    ///
    /// Deliberately excludes ``needsReauth``: a 401 is first answered with a token
    /// refresh, and only a failed refresh escalates to user action.
    var requiresUserAction: Bool {
        switch self {
        case .scopeDenied: true
        default: false
        }
    }

    /// Whether the caller should discard its incremental cursor and re-fetch fully.
    var requiresFullSync: Bool {
        switch self {
        case .fullSyncRequired: true
        default: false
        }
    }

    /// Whether a single forced token refresh should be attempted before giving up.
    var isAuthenticationFailure: Bool {
        switch self {
        case .needsReauth: true
        default: false
        }
    }

    /// Whether this failure says something about the *account's* connection
    /// rather than about the individual request.
    ///
    /// A rejected write (`forbiddenForNonOrganizer`, a duplicate ID, a stale
    /// ETag) is a property of that one request; recording it as account health
    /// would show the user a connection warning for a working connection.
    var isAccountLevel: Bool {
        switch self {
        case .needsReauth, .scopeDenied, .throttled, .server, .transport: true
        case .invalidRequest, .forbidden, .notFound, .conflict, .fullSyncRequired,
            .resourceDeleted, .preconditionFailed, .unexpected:
            false
        }
    }

    /// Server-suggested delay before retrying, when one was supplied.
    ///
    /// Google documents client-side backoff rather than `Retry-After` for this API,
    /// so this is honored when present but never depended upon.
    var retryAfter: TimeInterval? {
        switch self {
        case .throttled(_, let retryAfter): retryAfter
        default: nil
        }
    }

    // MARK: - Classification

    /// Google's `usageLimits` reason strings, all of which arrive as HTTP 403.
    private static let throttleReasons: Set<String> = [
        "rateLimitExceeded",
        "userRateLimitExceeded",
        "quotaExceeded",
        "dailyLimitExceeded",
        "dailyLimitExceededUnreg",
        "variableTermLimitExceeded",
    ]

    /// Reason strings that mean "the token does not carry the required scope".
    private static let scopeReasons: Set<String> = [
        "insufficientPermissions",
        "ACCESS_TOKEN_SCOPE_INSUFFICIENT",
        "insufficientFilePermissions",
    ]

    /// Reason strings that invalidate an incremental sync cursor.
    private static let fullSyncReasons: Set<String> = [
        "fullSyncRequired",
        "updatedMinTooLongAgo",
    ]

    /// Maps an HTTP response to a case using the status code *and* the reason
    /// string inside the JSON error envelope.
    static func classify(
        statusCode: Int,
        retryAfterHeader: String?,
        body: Data
    ) -> APIError {
        let envelope = GoogleErrorEnvelope(body)
        let reason = envelope.reason ?? ""
        let message = envelope.message ?? String(data: body, encoding: .utf8) ?? ""
        let retryAfter = retryAfterHeader.flatMap(TimeInterval.init)

        switch statusCode {
        case 400:
            return .invalidRequest(reason: reason, message: message)

        case 401:
            return .needsReauth(message: message)

        case 403:
            if throttleReasons.contains(reason) || envelope.domain == "usageLimits" {
                return .throttled(reason: reason, retryAfter: retryAfter)
            }
            if scopeReasons.contains(reason) {
                return .scopeDenied(reason: reason, message: message)
            }
            // An unrecognized 403 is deliberately *not* treated as scope loss:
            // guessing that way is what let throttling revoke a user's grant.
            return .forbidden(reason: reason, message: message)

        case 404:
            return .notFound(message: message)

        case 409:
            return .conflict(reason: reason, message: message)

        case 410:
            if fullSyncReasons.contains(reason) { return .fullSyncRequired(reason: reason) }
            if reason == "deleted" { return .resourceDeleted }
            // An unlabeled 410 on a list request is still a dead cursor.
            return .fullSyncRequired(reason: reason.isEmpty ? "gone" : reason)

        case 412:
            return .preconditionFailed(message: message)

        case 429:
            return .throttled(
                reason: reason.isEmpty ? "rateLimitExceeded" : reason,
                retryAfter: retryAfter
            )

        case 500...599:
            return .server(statusCode: statusCode, message: message)

        default:
            return .unexpected(
                statusCode: statusCode,
                body: String(data: body, encoding: .utf8) ?? ""
            )
        }
    }

    /// Wraps a `URLSession` transport failure, preserving cancellation.
    static func from(transportError error: Error) -> APIError {
        .transport((error as NSError).localizedDescription)
    }

    // MARK: - Description

    var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason, let message):
            "Invalid request (\(reason)): \(message)"
        case .needsReauth:
            "This account needs to be reconnected to Google."
        case .scopeDenied(let reason, _):
            "This account is missing a required permission (\(reason))."
        case .forbidden(let reason, let message):
            "Google refused the request (\(reason)): \(message)"
        case .throttled(let reason, _):
            "Rate limited by Google (\(reason))."
        case .notFound(let message):
            "Not found: \(message)"
        case .conflict(let reason, let message):
            "Conflict (\(reason)): \(message)"
        case .fullSyncRequired(let reason):
            "Sync cursor expired (\(reason)); a full sync is required."
        case .resourceDeleted:
            "The resource was deleted."
        case .preconditionFailed(let message):
            "Precondition failed: \(message)"
        case .server(let statusCode, let message):
            "Google server error \(statusCode): \(message)"
        case .transport(let message):
            "Network error: \(message)"
        case .unexpected(let statusCode, let body):
            "Unexpected HTTP \(statusCode): \(body)"
        }
    }
}

/// The JSON error body Google returns alongside a non-2xx status.
///
/// ```json
/// { "error": { "code": 403, "message": "…", "status": "PERMISSION_DENIED",
///              "errors": [ { "domain": "usageLimits", "reason": "rateLimitExceeded" } ] } }
/// ```
///
/// Decoding is best-effort — a proxy or gateway can return a non-JSON body with
/// any status, so every field is optional and failure yields an empty envelope.
nonisolated struct GoogleErrorEnvelope: Sendable {

    let code: Int?
    let message: String?
    let status: String?
    let domain: String?
    let reason: String?

    init(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
            self.init(code: nil, message: nil, status: nil, domain: nil, reason: nil)
            return
        }
        let first = decoded.error.errors?.first
        self.init(
            code: decoded.error.code,
            message: decoded.error.message,
            status: decoded.error.status,
            domain: first?.domain,
            reason: first?.reason
        )
    }

    private init(code: Int?, message: String?, status: String?, domain: String?, reason: String?) {
        self.code = code
        self.message = message
        self.status = status
        self.domain = domain
        self.reason = reason
    }

    private struct Payload: Decodable {
        let error: Body

        struct Body: Decodable {
            let code: Int?
            let message: String?
            let status: String?
            let errors: [Detail]?
        }

        struct Detail: Decodable {
            let domain: String?
            let reason: String?
            let message: String?
        }
    }
}
