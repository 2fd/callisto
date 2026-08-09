import Foundation
import SwiftData

/// Health of an account's connection to Google, independent of its granted scopes.
///
/// Kept separate from ``GoogleAccount/canRead`` and ``GoogleAccount/canWrite`` on
/// purpose: those describe what the *grant* allows and only change when the user
/// authorizes or revokes. This describes whether the last *network* attempt worked,
/// and never causes cached data to be discarded.
enum AccountSyncState: String, Sendable, CaseIterable {
    /// The last sync attempt succeeded.
    case ok
    /// Google rejected our credentials and refreshing them did not help.
    /// The user must re-run the consent flow.
    case needsReauth
    /// Google is rate limiting this account. Transient; see
    /// ``GoogleAccount/throttledUntil``.
    case throttled
    /// Repeated non-auth failures (server errors, offline). Transient.
    case failing
}

/// A Google account linked to Callisto.
///
/// Each account maps to a single Google identity. OAuth tokens are stored
/// separately in the macOS Keychain, keyed by ``accountId``.
///
/// - Important: Never persist OAuth tokens in SwiftData. Use ``KeychainService`` instead.
@Model
final class GoogleAccount {

    /// Google user ID (`sub` claim from the OpenID Connect response).
    @Attribute(.unique) var accountId: String
    /// The user's primary email address.
    var email: String
    /// Human-readable name shown in the account list.
    var displayName: String
    /// Whether this account's events are visible in the popover.
    /// Display-only filter — disabled accounts still sync from Google.
    var isVisible: Bool = true
    /// Whether the token currently has calendar read permission.
    var canRead: Bool = true
    /// Whether the token currently has event mutation permission.
    var canWrite: Bool = false
    /// Google multi-sign-in index injected as `authuser=N` when opening this
    /// account's calendar/meet URLs. `0` = first signed-in browser session.
    var authuser: Int = 0
    /// Timestamp of the last successful calendar sync, or `nil` if never synced.
    var lastSyncedAt: Date?

    // MARK: - Connection health

    /// Backing storage for ``syncState``. Persisted as a string so the enum can
    /// gain cases without a SwiftData migration.
    var syncStateRaw: String = AccountSyncState.ok.rawValue

    /// Earliest time this account may be contacted again after being throttled.
    var throttledUntil: Date?

    /// Consecutive failed sync cycles, reset on the first success.
    var consecutiveFailures: Int = 0

    /// Human-readable description of the most recent sync failure, for the UI.
    var lastSyncError: String?

    /// Health of the last sync attempt. Unknown raw values decode as ``AccountSyncState/ok``
    /// so a downgrade can never strand an account in a broken state.
    var syncState: AccountSyncState {
        get { AccountSyncState(rawValue: syncStateRaw) ?? .ok }
        set { syncStateRaw = newValue.rawValue }
    }

    /// Whether this account should be skipped for the current cycle because
    /// Google asked us to back off.
    var isThrottled: Bool {
        guard let throttledUntil else { return false }
        return throttledUntil > .now
    }

    /// Whether the account is usable for syncing right now: the grant allows
    /// reading and we are not inside a backoff window.
    var isSyncable: Bool {
        canRead && !isThrottled
    }

    init(
        accountId: String,
        email: String,
        displayName: String,
        isVisible: Bool = true,
        canRead: Bool = true,
        canWrite: Bool = false,
        authuser: Int = 0
    ) {
        self.accountId = accountId
        self.email = email
        self.displayName = displayName
        self.isVisible = isVisible
        self.canRead = canRead
        self.canWrite = canWrite
        self.authuser = authuser
    }
}
