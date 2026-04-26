import AuthenticationServices
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

  private let presentationProvider = AuthPresentationProvider()
  private var currentSession: ASWebAuthenticationSession?

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
  func token(for accountId: String) async throws -> String {
    if let existing = refreshTasks[accountId] {
      return try await existing.value
    }
    let task = Task<String, Error> {
      defer { refreshTasks[accountId] = nil }
      return try await loadOrRefresh(accountId: accountId)
    }
    refreshTasks[accountId] = task
    return try await task.value
  }

  /// Refreshes tokens for every account in parallel and returns the
  /// IDs that survived. Errors are logged and dropped.
  ///
  /// Visibility is a display-only filter — all accounts sync regardless of
  /// ``GoogleAccount/isVisible`` so re-enabling is instant.
  func authenticated() async -> [String] {
    let ids = accounts.filter(\.canRead).map(\.accountId)

    return await withTaskGroup(of: String?.self) { group in
      for id in ids {
        group.addTask { [weak self] in
          do {
            _ = try await self?.token(for: id)
            await self?.markSynced(id)
            return id
          } catch {
            await self?.logRefreshFailure(id, error: error)
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

  private func logRefreshFailure(_ accountId: String, error: Error) {
    Logger.shared.error(
      "Token refresh failed for \(accountId, privacy: .public): \(error.localizedDescription, privacy: .public)"
    )
  }

  private func bump() {
    version &+= 1
  }

  private func loadOrRefresh(accountId: String) async throws -> String {
    var tokens = try KeychainService.load(for: accountId)
    if tokens.isExpired {
      Logger.shared.debug(
        "Access token expired for \(accountId, privacy: .public), refreshing"
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

  /// Runs the PKCE OAuth consent flow and fetches the user's profile.
  private func runOAuthFlow(loginHint: String?) async -> (
    OAuthTokens, UserInfo
  )? {
    currentSession?.cancel()

    let verifier = PKCEHelper.generateVerifier()
    let challenge = PKCEHelper.generateChallenge(from: verifier)

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
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "prompt", value: "consent"),
    ]
    if let loginHint {
      items.append(URLQueryItem(name: "login_hint", value: loginHint))
      items.append(
        URLQueryItem(name: "include_granted_scopes", value: "true")
      )
    }
    components.queryItems = items

    do {
      let callbackURL = try await withCheckedThrowingContinuation {
        (cont: CheckedContinuation<URL, Error>) in
        let session = ASWebAuthenticationSession(
          url: components.url!,
          callbackURLScheme: AuthConfig.callbackScheme
        ) { url, error in
          if let error {
            cont.resume(throwing: error)
          } else if let url {
            cont.resume(returning: url)
          } else {
            cont.resume(throwing: AuthError.missingAuthCode)
          }
        }
        session.prefersEphemeralWebBrowserSession = true
        session.presentationContextProvider = presentationProvider
        self.currentSession = session
        session.start()
      }

      defer { currentSession = nil }

      let code = try extractAuthCode(from: callbackURL)
      let tokens = try await exchangeCode(code: code, verifier: verifier)
      let info = try await fetchUserInfo(accessToken: tokens.accessToken)
      return (tokens, info)
    } catch let error as ASWebAuthenticationSessionError
      where error.code == .canceledLogin
    {
      Logger.shared.info("User cancelled OAuth flow")
      currentSession = nil
      return nil
    } catch {
      Logger.shared.error(
        "OAuth flow failed: \(error.localizedDescription, privacy: .public)"
      )
      currentSession = nil
      return nil
    }
  }

  private func extractAuthCode(from url: URL) throws -> String {
    guard
      let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ),
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
      let body = String(data: data, encoding: .utf8) ?? ""
      throw APIError.httpError(statusCode: http.statusCode, body: body)
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

  var errorDescription: String? {
    switch self {
    case .missingAuthCode: "No authorization code received."
    case .tokenExchangeFailed(let detail):
      "Token exchange failed: \(detail)"
    case .noRefreshToken: "No refresh token available."
    case .refreshFailed(let detail): "Token refresh failed: \(detail)"
    case .userCancelled: "Authentication was cancelled."
    }
  }
}
