import Foundation
import SwiftData
import os

/// Owns the user's visible calendar list for every account and fetches
/// calendar metadata from Google.
///
/// Depends on ``GoogleAccountManager`` for access tokens. Sync always runs
/// ``GoogleAccountManager/authenticated()`` first to guarantee fresh tokens.
@MainActor @Observable
final class GoogleCalendarManager {

  let accounts: GoogleAccountManager
  private let modelContext: ModelContext
  private let api = GoogleCalendarAPI()

  private(set) var calendars: [GoogleCalendar] = []
  private var version: UInt64 = 0

  var isEmpty: Bool {
    calendars.isEmpty
  }

  init(accounts: GoogleAccountManager, container: ModelContainer) {
    self.accounts = accounts
    self.modelContext = ModelContext(container)
    self.calendars =
      (try? modelContext.fetch(FetchDescriptor<GoogleCalendar>())) ?? []
  }

  // MARK: - Iteration

  func iter() -> [GoogleCalendar] {
    _ = version
    let readableAccounts = Set(accounts.iter().filter(\.canRead).map(\.accountId))
    return calendars.filter { readableAccounts.contains($0.accountId) }
  }

  func iterByAccount(accountId: String) -> [GoogleCalendar] {
    guard accounts.get(accountId)?.canRead == true else { return [] }
    _ = version
    return calendars.filter { $0.accountId == accountId }
  }

  func get(calendarId: String) -> GoogleCalendar? {
    calendars.first { $0.calendarId == calendarId }
  }

  func forAccount(_ accountId: String) -> [GoogleCalendar] {
    guard accounts.get(accountId)?.canRead == true else { return [] }
    _ = version
    return calendars.filter { $0.accountId == accountId }
  }

  // MARK: - Mutation

  func toggleVisibility(_ calendar: GoogleCalendar) {
    applyVisibility(calendar, visible: !calendar.isVisible)
  }

  func setVisibility(_ calendar: GoogleCalendar, visible: Bool) {
    applyVisibility(calendar, visible: visible)
  }

  /// If the owning account is visible, updates only this calendar's flag.
  /// If the owning account is hidden, the change is interpreted as "solo this
  /// calendar": every other calendar on the account is hidden, this calendar
  /// and its account are made visible.
  private func applyVisibility(_ calendar: GoogleCalendar, visible: Bool) {
    let account = accounts.get(calendar.accountId)
    if account?.isVisible ?? true {
      calendar.isVisible = visible
    } else if let account {
      for cal in calendars where cal.accountId == account.accountId {
        cal.isVisible = (cal.calendarId == calendar.calendarId)
      }
      accounts.setVisibility(account, visible: true)
    } else {
      calendar.isVisible = visible
    }
    try? modelContext.save()
    version &+= 1
  }

  /// Stamps a calendar's `lastSyncedAt` after a successful event fetch for it.
  func markSynced(calendarId: String) {
    guard let calendar = get(calendarId: calendarId) else { return }
    calendar.lastSyncedAt = .now
    try? modelContext.save()
    version &+= 1
  }

  func logout(accountId: String) {
    let toRemove = calendars.filter { $0.accountId == accountId }
    for cal in toRemove { modelContext.delete(cal) }
    try? modelContext.save()
    calendars.removeAll { $0.accountId == accountId }
    version &+= 1
  }

  // MARK: - Sync

  /// Refreshes tokens then fetches every enabled account's calendar list in parallel.
  /// Returns `(accountId, calendarId)` pairs for every calendar present after sync.
  @discardableResult
  func sync() async -> [(String, String)] {
    let accountIds = await accounts.authenticated()
    guard !accountIds.isEmpty else { return [] }

    let fetched = await withTaskGroup(
      of: (String, [GCCalendarListEntry])?.self
    ) { group in
      for accountId in accountIds {
        group.addTask { [weak self] in
          guard let self else { return nil }
          do {
            let entries = try await self.fetch(accountId: accountId)
            return (accountId, entries)
          } catch {
            // Records health only — the cached calendar list is left intact.
            await self.accounts.recordSyncFailure(accountId, error: error)
            return nil
          }
        }
      }
      var out: [(String, [GCCalendarListEntry])] = []
      for await result in group {
        if let result { out.append(result) }
      }
      return out
    }

    var results: [(String, String)] = []
    for (accountId, entries) in fetched {
      applySync(accountId: accountId, entries: entries)
      accounts.markSynced(accountId)
      accounts.recordSyncSuccess(accountId)
      for entry in entries { results.append((accountId, entry.id)) }
    }

    version &+= 1
    return results
  }

  /// Fetches the calendar list for a single account via the Google Calendar API.
  func fetch(accountId: String) async throws -> [GCCalendarListEntry] {
    try await accounts.withToken(for: accountId) { token in
      try await api.listCalendars(accessToken: token).items
    }
  }

  // MARK: - Private

  private func applySync(accountId: String, entries: [GCCalendarListEntry]) {
    let existing = Dictionary(
      uniqueKeysWithValues:
        calendars
        .filter { $0.accountId == accountId }
        .map { ($0.calendarId, $0) }
    )
    var seen: Set<String> = []

    for entry in entries {
      seen.insert(entry.id)
      if let cal = existing[entry.id] {
        cal.update(from: entry)
      } else {
        let cal = GoogleCalendar(from: entry, accountId: accountId)
        modelContext.insert(cal)
        calendars.append(cal)
      }
    }

    for (id, cal) in existing where !seen.contains(id) {
      modelContext.delete(cal)
      calendars.removeAll { $0.calendarId == id }
    }

    try? modelContext.save()
  }
}
