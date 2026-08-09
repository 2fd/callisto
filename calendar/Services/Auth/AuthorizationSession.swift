import AppKit
import Foundation

/// Runs the authorization leg of the OAuth flow in the user's default browser
/// and waits for the custom-scheme redirect to arrive back through
/// `NSApplicationDelegate.application(_:open:)`.
///
/// `ASWebAuthenticationSession` was less code — it opened the page and captured
/// the redirect in one call — but on macOS it presents a sheet with no address
/// bar. Google's sensitive-scope verification requires a demonstration video
/// that shows "the browser address bar of the OAuth consent screen correctly
/// includes your app's OAuth client ID", which that sheet can never satisfy.
/// Callisto requests three sensitive Calendar scopes, so this is not optional.
///
/// The system browser is also what RFC 8252 recommends for native apps, and it
/// reuses the user's existing Google sessions — linking a second account no
/// longer means retyping a password, which is what
/// ``GoogleAccount/authuser`` already assumes.
///
/// Reference: https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification
@MainActor
final class AuthorizationSession {

    /// A flow that has opened a browser tab and is waiting for its redirect.
    private struct Pending {
        let state: String
        let continuation: CheckedContinuation<URL, Error>
        /// Resumes ``continuation`` with ``AuthError/timedOut`` if the redirect
        /// never comes. Nothing else can: closing a browser tab produces no
        /// event, so without this the flow would wait forever.
        let expiry: Task<Void, Never>
    }

    private var pending: Pending?

    /// Whether a browser flow is currently waiting for its redirect.
    var isAuthorizing: Bool { pending != nil }

    /// Opens `url` in the default browser and returns the redirect URL carrying
    /// the matching `state`.
    ///
    /// Starting a new authorization abandons one that is still waiting — the
    /// user pressed the button again, so the older tab is stale.
    func authorize(
        url: URL,
        state: String,
        timeout: Duration = .seconds(180)
    ) async throws -> URL {
        cancel()

        guard NSWorkspace.shared.open(url) else {
            throw AuthError.browserUnavailable
        }

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in
            let expiry = Task { [weak self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self?.finish(throwing: AuthError.timedOut)
            }
            pending = Pending(
                state: state,
                continuation: continuation,
                expiry: expiry
            )
        }
    }

    /// Delivers a redirect URL to the waiting flow.
    ///
    /// Returns `false` when the URL belongs to no flow this process started: a
    /// stale tab, or — when Callisto and Callisto Nightly are both installed —
    /// a redirect LaunchServices handed to the wrong copy, since both register
    /// the same URL scheme (it is derived from the shared client ID). Dropping
    /// it is the only safe answer; resuming the wrong flow would exchange a
    /// code against the wrong PKCE verifier.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let pending else { return false }
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.queryItems?.first(where: { $0.name == "state" })?.value
                == pending.state
        else { return false }

        self.pending = nil
        pending.expiry.cancel()
        pending.continuation.resume(returning: url)
        // The app is an accessory: without this the settings window stays
        // behind the browser the user was just looking at.
        NSApp.activate()
        return true
    }

    /// Abandons a flow that is still waiting for its redirect.
    func cancel() {
        finish(throwing: AuthError.userCancelled)
    }

    private func finish(throwing error: Error) {
        guard let pending else { return }
        self.pending = nil
        pending.expiry.cancel()
        pending.continuation.resume(throwing: error)
    }
}
