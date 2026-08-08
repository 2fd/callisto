import Foundation

/// Truncated exponential backoff with jitter, in the form Google documents for
/// its APIs: `min((2^n) + random_number_milliseconds, maximum_backoff)`, where
/// the jitter is "a random number of milliseconds less than or equal to 1,000"
/// and exists to stop many clients retrying in lockstep after a shared outage.
///
/// Reference: https://developers.google.com/workspace/calendar/api/guides/quota
nonisolated enum Backoff {

    /// Ceiling on any single wait, in seconds. Google's guidance is to stop
    /// growing the interval at 32–64s and keep retrying at that cadence.
    static let maximumDelay: TimeInterval = 64

    /// Highest exponent applied before the cap takes over. Beyond this the
    /// `pow` result is discarded by `min` anyway.
    private static let maximumExponent = 6

    /// Delay before retry number `attempt` (1-based).
    static func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponent = min(max(attempt, 1), maximumExponent)
        let base = pow(2.0, Double(exponent))
        let jitter = Double.random(in: 0...1)
        return min(base + jitter, maximumDelay)
    }

    /// Delay before retry number `attempt`, preferring a server-supplied
    /// `Retry-After` when one was sent.
    ///
    /// Google documents client-side backoff rather than `Retry-After` for the
    /// Calendar API, so the header is honored opportunistically and clamped to
    /// ``maximumDelay`` so a bad value cannot stall syncing indefinitely.
    static func delay(forAttempt attempt: Int, retryAfter: TimeInterval?) -> TimeInterval {
        guard let retryAfter, retryAfter > 0 else { return delay(forAttempt: attempt) }
        return min(retryAfter, maximumDelay)
    }
}

/// How many times a request is retried, and how long to wait between attempts.
///
/// Injected so tests can exercise the retry loop without sleeping through real
/// backoff intervals.
nonisolated struct RetryPolicy: Sendable {

    /// Attempts per request, including the first.
    let maxAttempts: Int

    /// Wait before retry number `attempt`, given any server-supplied delay.
    let delay: @Sendable (_ attempt: Int, _ retryAfter: TimeInterval?) -> TimeInterval

    /// Google's documented backoff, capped at four attempts.
    ///
    /// Google's guidance is to keep retrying at the capped interval, but a menu
    /// bar app polling on a timer gets another chance next cycle, so a short
    /// ceiling beats holding a task slot for minutes.
    static let standard = RetryPolicy(maxAttempts: 4) { attempt, retryAfter in
        Backoff.delay(forAttempt: attempt, retryAfter: retryAfter)
    }
}
