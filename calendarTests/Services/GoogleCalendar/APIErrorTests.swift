import Foundation
import Testing

@testable import calendar

/// The classifier is the load-bearing part of the error layer: every retry,
/// backoff and permission decision downstream reads from it. These cases are
/// taken from Google's documented error table.
///
/// Reference: https://developers.google.com/workspace/calendar/api/guides/errors
@Suite("APIError classification")
struct APIErrorTests {

    private func body(reason: String, domain: String = "global", status: String? = nil)
        -> Data
    {
        let statusLine = status.map { "\"status\": \"\($0)\"," } ?? ""
        return Data(
            """
            {
              "error": {
                "code": 403,
                \(statusLine)
                "message": "Some message",
                "errors": [ { "domain": "\(domain)", "reason": "\(reason)", "message": "Some message" } ]
              }
            }
            """.utf8
        )
    }

    private func classify(_ code: Int, _ payload: Data, retryAfter: String? = nil)
        -> APIError
    {
        APIError.classify(statusCode: code, retryAfterHeader: retryAfter, body: payload)
    }

    // MARK: - 403 is ambiguous

    @Test("403 rateLimitExceeded is throttling, not lost permission")
    func rateLimitIsThrottle() {
        let error = classify(403, body(reason: "rateLimitExceeded", domain: "usageLimits"))
        guard case .throttled = error else {
            Issue.record("expected .throttled, got \(error)")
            return
        }
        #expect(error.isRetryable)
        #expect(!error.requiresUserAction)
    }

    @Test("403 userRateLimitExceeded is throttling")
    func userRateLimitIsThrottle() {
        let error = classify(403, body(reason: "userRateLimitExceeded", domain: "usageLimits"))
        guard case .throttled = error else {
            Issue.record("expected .throttled, got \(error)")
            return
        }
        #expect(!error.requiresUserAction)
    }

    @Test("403 quotaExceeded is throttling")
    func quotaExceededIsThrottle() {
        let error = classify(403, body(reason: "quotaExceeded", domain: "usageLimits"))
        #expect(error.isRetryable)
        #expect(!error.requiresUserAction)
    }

    @Test("403 insufficientPermissions is a real scope failure")
    func insufficientPermissionsIsScopeDenied() {
        let error = classify(403, body(reason: "insufficientPermissions"))
        guard case .scopeDenied = error else {
            Issue.record("expected .scopeDenied, got \(error)")
            return
        }
        #expect(error.requiresUserAction)
        #expect(!error.isRetryable)
    }

    @Test("403 ACCESS_TOKEN_SCOPE_INSUFFICIENT is a real scope failure")
    func accessTokenScopeInsufficientIsScopeDenied() {
        let error = classify(
            403,
            body(reason: "ACCESS_TOKEN_SCOPE_INSUFFICIENT", status: "PERMISSION_DENIED")
        )
        #expect(error.requiresUserAction)
    }

    @Test("An unrecognized 403 never revokes the grant")
    func unknownForbiddenDoesNotRevoke() {
        let error = classify(403, body(reason: "forbiddenForNonOrganizer"))
        guard case .forbidden = error else {
            Issue.record("expected .forbidden, got \(error)")
            return
        }
        #expect(!error.requiresUserAction)
        #expect(!error.isAccountLevel)
    }

    @Test("A 403 with an unparseable body never revokes the grant")
    func malformedForbiddenDoesNotRevoke() {
        let error = classify(403, Data("<html>gateway error</html>".utf8))
        #expect(!error.requiresUserAction)
    }

    // MARK: - Auth

    @Test("401 asks for a refresh, not for user action")
    func unauthorizedIsRefreshable() {
        let error = classify(401, body(reason: "authError"))
        #expect(error.isAuthenticationFailure)
        #expect(!error.requiresUserAction)
    }

    // MARK: - Sync cursor

    @Test("410 fullSyncRequired invalidates the cursor")
    func fullSyncRequired() {
        let error = classify(410, body(reason: "fullSyncRequired"))
        #expect(error.requiresFullSync)
    }

    @Test("410 updatedMinTooLongAgo invalidates the cursor")
    func updatedMinTooLongAgo() {
        let error = classify(410, body(reason: "updatedMinTooLongAgo"))
        #expect(error.requiresFullSync)
    }

    @Test("410 deleted is the only authoritative deletion signal")
    func resourceDeleted() {
        let error = classify(410, body(reason: "deleted"))
        #expect(error == .resourceDeleted)
        #expect(!error.requiresFullSync)
    }

    // MARK: - Transient

    @Test("404 is transient per Google's table, not proof of deletion")
    func notFoundIsRetryable() {
        let error = classify(404, body(reason: "notFound"))
        #expect(error.isRetryable)
        guard case .notFound = error else {
            Issue.record("expected .notFound, got \(error)")
            return
        }
    }

    @Test("429 is throttling")
    func tooManyRequestsIsThrottle() {
        let error = classify(429, body(reason: "rateLimitExceeded"))
        #expect(error.isRetryable)
    }

    @Test("Retry-After is honored when Google sends one")
    func honorsRetryAfter() {
        let error = classify(429, body(reason: "rateLimitExceeded"), retryAfter: "30")
        #expect(error.retryAfter == 30)
    }

    @Test("A missing Retry-After leaves the delay to the caller's backoff")
    func missingRetryAfter() {
        let error = classify(429, body(reason: "rateLimitExceeded"))
        #expect(error.retryAfter == nil)
    }

    @Test("5xx is retryable")
    func serverErrorIsRetryable() {
        let error = classify(500, body(reason: "backendError"))
        #expect(error.isRetryable)
        #expect(error.isAccountLevel)
    }

    // MARK: - Client bugs

    @Test("400 is never retried")
    func badRequestIsNotRetryable() {
        let error = classify(400, body(reason: "timeRangeEmpty"))
        #expect(!error.isRetryable)
        #expect(!error.isAccountLevel)
    }

    // MARK: - Envelope

    @Test("The error envelope decodes Google's nested shape")
    func envelopeDecoding() {
        let envelope = GoogleErrorEnvelope(
            body(reason: "rateLimitExceeded", domain: "usageLimits", status: "PERMISSION_DENIED")
        )
        #expect(envelope.reason == "rateLimitExceeded")
        #expect(envelope.domain == "usageLimits")
        #expect(envelope.status == "PERMISSION_DENIED")
        #expect(envelope.code == 403)
    }

    @Test("A non-JSON body yields an empty envelope rather than throwing")
    func envelopeTolerantOfGarbage() {
        let envelope = GoogleErrorEnvelope(Data("not json".utf8))
        #expect(envelope.reason == nil)
        #expect(envelope.code == nil)
    }
}

/// Backoff must be bounded and jittered, per Google's documented formula
/// `min((2^n) + random_ms, maximum_backoff)`.
@Suite("Backoff")
struct BackoffTests {

    @Test("Delay grows with consecutive failures")
    func growsWithFailures() {
        #expect(Backoff.delay(forAttempt: 1) < Backoff.delay(forAttempt: 5))
    }

    @Test("Delay is capped")
    func isCapped() {
        for attempt in 1...20 {
            #expect(Backoff.delay(forAttempt: attempt) <= Backoff.maximumDelay)
        }
    }

    @Test("Delay is never zero or negative")
    func isPositive() {
        for attempt in 0...10 {
            #expect(Backoff.delay(forAttempt: attempt) > 0)
        }
    }

    @Test("A server-supplied Retry-After wins over the computed delay")
    func retryAfterWins() {
        #expect(Backoff.delay(forAttempt: 1, retryAfter: 12) == 12)
    }

    @Test("An absurd Retry-After is clamped so syncing cannot stall")
    func retryAfterClamped() {
        #expect(Backoff.delay(forAttempt: 1, retryAfter: 86_400) == Backoff.maximumDelay)
    }

    @Test("A nonsensical Retry-After falls back to computed backoff")
    func retryAfterIgnoredWhenInvalid() {
        #expect(Backoff.delay(forAttempt: 1, retryAfter: -5) > 0)
    }
}
