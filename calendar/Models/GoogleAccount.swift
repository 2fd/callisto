import Foundation
import SwiftData

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
