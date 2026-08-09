import Foundation
import SwiftData
import os

/// Owns the account list, OAuth consent flow, Keychain tokens, and token refresh.
///
/// Folds the former ``GoogleAuthService`` (OAuth) and ``AccountSync`` (refresh)
/// into a single main-actor manager. Concurrent `authenticated()` calls share a
/// single in-flight refresh per account via ``refreshTasks``.
@MainActor @Observable
final class GoogleAccountManager {

  // MARK: - State

  private let modelContext: ModelContext
  private(set) var accounts: [GoogleAccount] = []

  /// Observation counter read inside ``iter()`` so `@Observable` tracks
  /// method-based access and views re-render on mutation.
  private var version: UInt64 = 0

  // MARK: - OAuth

  private let authorization = AuthorizationSession()

  /// Whether a consent flow is waiting on the browser. Drives the "Cancel"
  /// affordance in Settings — the browser cannot tell us the user closed the
  /// tab, so the only way out is for them to say so.
  private(set) var isAuthorizing = false

  /// Distinguishes concurrent consent attempts so a flow that has already been
  /// superseded cannot clear ``isAuthorizing`` out from under its replacement.
  private var authorizationGeneration: UInt64 = 0

  // MARK: - Refresh coalescing

  /// One in-flight refresh per account; concurrent callers await the same task.
  private var refreshTasks: [String: Task<String, Error>] = [:]

  var isEmpty: Bool {
    accounts.isEmpty
  }

  // MARK: - Init

  init(container: ModelContainer) {
    self.modelContext = ModelContext(container)
    self.accounts =
      (try? modelContext.fetch(FetchDescriptor<GoogleAccount>())) ?? []
    reconcilePermissionsFromKeychain()
  }

  // MARK: - Iteration

  func iter() -> [GoogleAccount] {
    _ = version
    return accounts
  }

  func get(_ accountId: String) -> GoogleAccount? {
    accounts.first { $0.accountId == accountId }
  }

  // MARK: - Mutation

  /// Runs the OAuth consent flow and inserts or updates the resulting account.
  /// Returns `nil` if the user cancelled or the flow failed.
  func upsert() async -> GoogleAccount? {
    guard let (tokens, info) = await runOAuthFlow(loginHint: nil) else {
      return nil
    }

    do {
      try KeychainService.save(tokens: tokens, for: info.sub)
    } catch {
      Logger.shared.error(
        "Failed to save tokens for \(info.sub, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return nil
    }

    if let existing = get(info.sub) {
      existing.email = info.email
      existing.displayName = info.name ?? info.email
      existing.canRead = tokens.canRead
      existing.canWrite = tokens.canWrite
      try? modelContext.save()
      bump()
      return existing
    }

    let account = GoogleAccount(
      accountId: info.sub,
      email: info.email,
      displayName: info.name ?? info.email,
      canRead: tokens.canRead,
      canWrite: tokens.canWrite
    )
    modelContext.insert(account)
    try? modelContext.save()
    accounts.append(account)
    bump()
    return account
  }

  /// Re-authorizes an existing account to request missing calendar read scope.
  func grantReadPermission(_ account: GoogleAccount) async -> GoogleAccount {
    await reauthorize(account)
  }

  /// Re-authorizes an existing account to request the events write scope.
  func grantWritePermission(_ account: GoogleAccount) async -> GoogleAccount {
    await reauthorize(account)
  }

  private func reauthorize(_ account: GoogleAccount) async -> GoogleAccount {
    guard let (tokens, info) = await runOAuthFlow(loginHint: account.email)
    else { return account }

    guard info.sub == account.accountId else {
      Logger.shared.error(
        "Reauthorization returned account \(info.sub, privacy: .public), expected \(account.accountId, privacy: .public)"
      )
      return account
    }

    do {
      try KeychainService.save(tokens: tokens, for: account.accountId)
      account.email = info.email
      account.displayName = info.name ?? info.email
      account.canRead = tokens.canRead
      account.canWrite = tokens.canWrite
      try modelContext.save()
      bump()
    } catch {
      Logger.shared.error(
        "Failed to save upgraded tokens: \(error.localizedDescription, privacy: .public)"
      )
    }
    return account
  }

  func logout(_ account: GoogleAccount) async {
    try? KeychainService.delete(for: account.accountId)
    refreshTasks[account.accountId] = nil
    modelContext.delete(account)
    try? modelContext.save()
    accounts.removeAll { $0.accountId == account.accountId }
    bump()
  }

  func toggleVisibility(_ account: GoogleAccount) {
    account.isVisible = !account.isVisible
    try? modelContext.save()
    bump()
  }

  func setVisibility(_ account: GoogleAccount, visible: Bool) {
    account.isVisible = visible
    try? modelContext.save()
    bump()
  }

  func setAuthUser(_ account: GoogleAccount, authuser: Int) {
    account.authuser = max(0, authuser)
    try? modelContext.save()
    bump()
  }

  /// Returns the account's `authuser` value, or `0` if the account is unknown.
  func getAuthUser(_ accountId: String) -> Int {
    get(accountId)?.authuser ?? 0
  }

  /// Marks an account as missing calendar read permission.
  ///
  /// - Important: Call this only for a confirmed scope failure
  ///   (``APIError/scopeDenied``), never for a transport, quota or server error.
  ///   It hides every calendar and event the account owns from the UI.
  func markReadPermissionDenied(_ accountId: String) {
    guard let account = get(accountId), account.canRead else { return }
    account.canRead = false
    account.canWrite = false
    try? modelContext.save()
    bump()
  }

  /// Marks an account as missing event mutation permission.
  func markWritePermissionDenied(_ accountId: String) {
    guard let account = get(accountId), account.canWrite else { return }
    account.canWrite = false
    try? modelContext.save()
    bump()
  }

  // MARK: - Token access for other managers

  /// Returns a valid access token for the account, refreshing if expired.
  /// Concurrent callers for the same account share a single refresh task.
  ///
  /// - Parameter forceRefresh: Refresh even when the cached token has not yet
  ///   expired by the clock. Required to recover from a 401, where the token
  ///   *looks* valid locally but Google has already invalidated it — clock skew,
  ///   a server-side revocation, or a scope change all produce this.
  ///   A forced refresh supersedes any in-flight coalesced refresh, since the
  ///   caller has just seen a 401 for the token that one would return.
  func token(for accountId: String, forceRefresh: Bool = false) async throws
    -> String
  {
    if !forceRefresh, let existing = refreshTasks[accountId] {
      return try await existing.value
    }
    let task = Task<String, Error> {
      defer { refreshTasks[accountId] = nil }
      return try await loadOrRefresh(accountId: accountId, force: forceRefresh)
    }
    refreshTasks[accountId] = task
    return try await task.value
  }

  /// Runs `operation` with a valid access token for the account, and on a 401
  /// forces a token refresh and retries exactly once.
  ///
  /// Google's documented action for `401 authError` is "get a new access token
  /// using the long-lived refresh token" — a 401 is an instruction to refresh,
  /// not a verdict on the account. Only a 401 that survives a fresh token is
  /// escalated to the caller.
  func withToken<T>(
    for accountId: String,
    _ operation: (String) async throws -> T
  ) async throws -> T {
    let token = try await token(for: accountId)
    do {
      return try await operation(token)
    } catch let error as APIError where error.isAuthenticationFailure {
      Logger.shared.info(
        "Retrying with a forced token refresh for \(accountId, privacy: .public)"
      )
      let refreshed = try await self.token(for: accountId, forceRefresh: true)
      return try await operation(refreshed)
    }
  }

  /// Refreshes tokens for every syncable account in parallel and returns the
  /// IDs that survived.
  ///
  /// Visibility is a display-only filter — all accounts sync regardless of
  /// ``GoogleAccount/isVisible`` so re-enabling is instant. Accounts inside a
  /// backoff window are skipped for this cycle.
  func authenticated() async -> [String] {
    let ids = accounts.filter(\.isSyncable).map(\.accountId)

    return await withTaskGroup(of: String?.self) { group in
      for id in ids {
        group.addTask { [weak self] in
          do {
            _ = try await self?.token(for: id)
            await self?.markSynced(id)
            return id
          } catch {
            await self?.recordSyncFailure(id, error: error)
            return nil
          }
        }
      }
      var surviving: [String] = []
      for await result in group {
        if let result { surviving.append(result) }
      }
      return surviving
    }
  }

  // MARK: - Connection health

  /// Records that an operation against this account succeeded, clearing any
  /// throttle or failure state.
  func recordSyncSuccess(_ accountId: String) {
    guard let account = get(accountId) else { return }
    guard account.syncState != .ok || account.consecutiveFailures > 0
        || account.throttledUntil != nil
    else { return }
    account.syncState = .ok
    account.throttledUntil = nil
    account.consecutiveFailures = 0
    account.lastSyncError = nil
    try? modelContext.save()
    bump()
  }

  /// Records a failed operation against this account.
  ///
  /// - Important: This never deletes cached calendars or events. A network
  ///   failure says nothing about whether the data we already hold is correct,
  ///   and dropping it turns a transient outage into a re-authorization prompt
  ///   plus an empty popover.
  func recordSyncFailure(_ accountId: String, error: Error) {
    guard let account = get(accountId) else { return }

    // Request-scoped refusals (wrong organizer, stale ETag, duplicate ID) say
    // nothing about the connection and must not raise a warning on the account.
    if let apiError = error as? APIError, !apiError.isAccountLevel {
      Logger.shared.error(
        "Request failed for \(accountId, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
      return
    }

    account.consecutiveFailures += 1
    account.lastSyncError = error.localizedDescription

    switch error {
    case let apiError as APIError:
      apply(apiError, to: account)
    case let authError as AuthError:
      // A refresh that Google rejected outright means the grant is gone.
      account.syncState = authError.requiresReauthorization ? .needsReauth : .failing
    default:
      account.syncState = .failing
    }

    Logger.shared.error(
      "Sync failure for \(accountId, privacy: .public) [\(account.syncStateRaw, privacy: .public)]: \(error.localizedDescription, privacy: .public)"
    )
    try? modelContext.save()
    bump()
  }

  private func apply(_ error: APIError, to account: GoogleAccount) {
    switch error {
    case .throttled(_, let retryAfter):
      account.syncState = .throttled
      account.throttledUntil = .now.addingTimeInterval(
        Backoff.delay(
          forAttempt: account.consecutiveFailures,
          retryAfter: retryAfter
        )
      )

    case .scopeDenied:
      // The only case that may narrow the grant — and even then the cache stays.
      account.syncState = .needsReauth
      markReadPermissionDenied(account.accountId)

    case .needsReauth:
      // Reached only after a forced refresh already failed to help.
      account.syncState = .needsReauth

    default:
      account.syncState = .failing
    }
  }


  // MARK: - Sync tracking

  /// Stamps the account's `lastSyncedAt` to now. Called after each
  /// successful per-account milestone: token refresh, calendar-list
  /// fetch, and event fetch.
  func markSynced(_ accountId: String) {
    guard let account = get(accountId) else { return }
    account.lastSyncedAt = .now
    try? modelContext.save()
    bump()
  }

  // MARK: - Private

  private func reconcilePermissionsFromKeychain() {
    var changed = false
    for account in accounts {
      guard let tokens = try? KeychainService.load(for: account.accountId) else {
        continue
      }
      changed = applyPermissions(from: tokens, to: account) || changed
    }
    if changed {
      try? modelContext.save()
      bump()
    }
  }

  @discardableResult
  private func applyPermissions(from tokens: OAuthTokens, accountId: String) -> Bool {
    guard let account = get(accountId) else { return false }
    let changed = applyPermissions(from: tokens, to: account)
    if changed {
      try? modelContext.save()
      bump()
    }
    return changed
  }

  @discardableResult
  private func applyPermissions(from tokens: OAuthTokens, to account: GoogleAccount) -> Bool {
    let canRead = tokens.canRead
    let canWrite = tokens.canWrite
    guard account.canRead != canRead || account.canWrite != canWrite else {
      return false
    }
    account.canRead = canRead
    account.canWrite = canWrite
    return true
  }

  private func bump() {
    version &+= 1
  }

  private func loadOrRefresh(accountId: String, force: Bool = false) async throws
    -> String
  {
    var tokens = try KeychainService.load(for: accountId)
    if force || tokens.isExpired {
      Logger.shared.debug(
        "Refreshing access token for \(accountId, privacy: .public) (forced: \(force, privacy: .public))"
      )
      tokens = try await refreshTokens(
        accountId: accountId,
        existing: tokens
      )
    }
    if !tokens.grantedScopes.isEmpty {
      applyPermissions(from: tokens, accountId: accountId)
    }
    return tokens.accessToken
  }

  private func refreshTokens(accountId: String, existing: OAuthTokens)
    async throws -> OAuthTokens
  {
    guard !existing.refreshToken.isEmpty else {
      Logger.shared.error(
        "No refresh token for \(accountId, privacy: .public)"
      )
      throw AuthError.noRefreshToken
    }

    let request = URLRequest(
      formPost: URL(string: AuthConfig.tokenEndpoint)!,
      parameters: [
        "client_id": AuthConfig.clientId,
        "grant_type": "refresh_token",
        "refresh_token": existing.refreshToken,
      ]
    )

    let (data, _) = try await URLSession.shared.data(for: request)

    let tokens: OAuthTokens
    do {
      tokens = try OAuthTokens(
        fromTokenResponse: data,
        fallbackRefreshToken: existing.refreshToken,
        fallbackScopes: existing.grantedScopes
      )
    } catch {
      Logger.shared.error(
        "Token refresh failed: \(error.localizedDescription, privacy: .public)"
      )
      throw AuthError.refreshFailed(
        String(data: data, encoding: .utf8) ?? "Unknown error"
      )
    }
    try KeychainService.save(tokens: tokens, for: accountId)
    return tokens
  }

  // MARK: - OAuth flow

  private struct UserInfo: Codable, Sendable {
    let sub: String
    let email: String
    let name: String?
  }

  /// Abandons a consent flow that is still waiting on the browser.
  func cancelAuthorization() {
    authorization.cancel()
  }

  /// Routes an OAuth redirect delivered to the app's URL scheme.
  ///
  /// Returns `false` if it matches no in-flight flow, so `AppDelegate` can log
  /// the URL as unhandled rather than swallowing it.
  @discardableResult
  func handleAuthorizationCallback(_ url: URL) -> Bool {
    authorization.handle(url)
  }

  /// Runs the PKCE OAuth consent flow and fetches the user's profile.
  private func runOAuthFlow(loginHint: String?) async -> (
    OAuthTokens, UserInfo
  )? {
    let verifier = PKCEHelper.generateVerifier()
    let challenge = PKCEHelper.generateChallenge(from: verifier)
    let state = PKCEHelper.generateState()

    var components = URLComponents(
      string: AuthConfig.authorizationEndpoint
    )!
    var items = [
      URLQueryItem(name: "client_id", value: AuthConfig.clientId),
      URLQueryItem(name: "redirect_uri", value: AuthConfig.redirectURI),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(
        name: "scope",
        value: AuthConfig.scopes.joined(separator: " ")
      ),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "prompt", value: "consent"),
    ]
    if let loginHint {
      items.append(URLQueryItem(name: "login_hint", value: loginHint))
    }
    components.queryItems = items

    authorizationGeneration &+= 1
    let generation = authorizationGeneration
    isAuthorizing = true
    defer {
      // A superseded flow must not clear the flag its replacement just set.
      if generation == authorizationGeneration { isAuthorizing = false }
    }

    do {
      let callbackURL = try await authorization.authorize(
        url: components.url!,
        state: state
      )
      let code = try extractAuthCode(from: callbackURL, expectedState: state)
      let tokens = try await exchangeCode(code: code, verifier: verifier)
      let info = try await fetchUserInfo(accessToken: tokens.accessToken)
      return (tokens, info)
    } catch AuthError.userCancelled {
      Logger.shared.info("User cancelled OAuth flow")
      return nil
    } catch {
      Logger.shared.error(
        "OAuth flow failed: \(error.localizedDescription, privacy: .public)"
      )
      return nil
    }
  }

  private func extractAuthCode(from url: URL, expectedState: String) throws
    -> String
  {
    guard
      let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      )
    else {
      throw AuthError.missingAuthCode
    }

    let returnedState = components.queryItems?.first { $0.name == "state" }?
      .value
    guard returnedState == expectedState else {
      throw AuthError.invalidState
    }

    guard
      let code = components.queryItems?.first(where: { $0.name == "code" }
      )?.value
    else {
      throw AuthError.missingAuthCode
    }

    return code
  }

  private func exchangeCode(code: String, verifier: String) async throws
    -> OAuthTokens
  {
    let request = URLRequest(
      formPost: URL(string: AuthConfig.tokenEndpoint)!,
      parameters: [
        "client_id": AuthConfig.clientId,
        "code": code,
        "code_verifier": verifier,
        "grant_type": "authorization_code",
        "redirect_uri": AuthConfig.redirectURI,
      ]
    )

    let (data, _) = try await URLSession.shared.data(for: request)
    do {
      return try OAuthTokens(fromTokenResponse: data)
    } catch {
      let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
      Logger.shared.error(
        "Token exchange failed: \(msg, privacy: .public)"
      )
      throw AuthError.tokenExchangeFailed(msg)
    }
  }

  private func fetchUserInfo(accessToken: String) async throws -> UserInfo {
    var request = URLRequest(
      url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!
    )
    request.setValue(
      "Bearer \(accessToken)",
      forHTTPHeaderField: "Authorization"
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    if let http = response as? HTTPURLResponse,
      !(200...299).contains(http.statusCode)
    {
      throw APIError.classify(
        statusCode: http.statusCode,
        retryAfterHeader: http.value(forHTTPHeaderField: "Retry-After"),
        body: data
      )
    }

    return try JSONDecoder().decode(UserInfo.self, from: data)
  }
}

// MARK: - AuthError (formerly owned by GoogleAuthService)

nonisolated enum AuthError: LocalizedError, Sendable {
  case missingAuthCode
  case tokenExchangeFailed(String)
  case noRefreshToken
  case refreshFailed(String)
  case userCancelled
  case invalidState
  case browserUnavailable
  case timedOut

  var errorDescription: String? {
    switch self {
    case .missingAuthCode: "No authorization code received."
    case .tokenExchangeFailed(let detail):
      "Token exchange failed: \(detail)"
    case .noRefreshToken: "No refresh token available."
    case .refreshFailed(let detail): "Token refresh failed: \(detail)"
    case .userCancelled: "Authentication was cancelled."
    case .invalidState: "OAuth state validation failed."
    case .browserUnavailable: "Could not open a browser to sign in."
    case .timedOut: "Sign-in timed out waiting for the browser."
    }
  }

  /// Whether recovering requires the user to re-run the consent flow.
  ///
  /// Google answers a revoked, expired or superseded refresh token with
  /// `invalid_grant`; every other refresh failure (offline, 5xx, malformed
  /// response) is transient and must not cost the user their grant.
  var requiresReauthorization: Bool {
    switch self {
    case .noRefreshToken, .invalidState, .missingAuthCode:
      true
    case .refreshFailed(let detail), .tokenExchangeFailed(let detail):
      detail.localizedCaseInsensitiveContains("invalid_grant")
    case .userCancelled, .browserUnavailable, .timedOut:
      // The user never got as far as answering; the existing grant is intact.
      false
    }
  }
}
