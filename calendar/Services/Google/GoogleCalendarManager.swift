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
  private let api: any CalendarAPI

  private(set) var calendars: [GoogleCalendar] = []
  private var version: UInt64 = 0

  /// Color palettes, keyed by account. Accounts absent from the map — not yet
  /// synced, or whose palette fetch failed — fall back to
  /// ``ColorPalette/googleDefaults``.
  private(set) var colorPalettes: [String: ColorPalette] = [:]

  var isEmpty: Bool {
    calendars.isEmpty
  }

  init(
    accounts: GoogleAccountManager,
    container: ModelContainer,
    api: any CalendarAPI = GoogleCalendarAPI()
  ) {
    self.accounts = accounts
    self.api = api
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

  /// The color palette in force for an account.
  func palette(for accountId: String) -> ColorPalette {
    colorPalettes[accountId] ?? .googleDefaults
  }

  /// The color an event should be drawn in: its own when it has one, otherwise
  /// the color of the calendar it lives on.
  ///
  /// Most events carry no `colorId` at all — Google only sets one when the user
  /// deliberately recolors a single event — so the calendar's color is the
  /// common answer. That one is resolved from the calendar's `colorId` rather
  /// than taken from `backgroundColor`, because Google resolves the entry
  /// against the same legacy table the `colors` endpoint serves: a Peacock
  /// calendar arrives as `#9fe1e7` where the product draws `#039be5`. Only a
  /// calendar with a custom RGB color has no ID to resolve, and there
  /// `backgroundColor` is the real answer.
  func color(for event: GoogleCalendarEvent, in calendar: GoogleCalendar) -> String {
    palette(for: event.accountId).event(event.colorId) ?? color(for: calendar)
  }

  /// The color that stands for a calendar itself.
  func color(for calendar: GoogleCalendar) -> String {
    palette(for: calendar.accountId).calendar(calendar.colorId)
      ?? calendar.backgroundColor
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

  /// Decides how the next event fetch for this calendar should be issued.
  ///
  /// A full read is required when there is no cursor, when the window has moved
  /// to a new day (events that entered the window were not *modified*, so
  /// `updatedMin` would not return them), or when the last full read is old
  /// enough that a missed change would be worth catching.
  func syncMode(for calendarId: String, windowStart: Date) -> EventSyncMode {
    guard let calendar = get(calendarId: calendarId),
      let cursor = calendar.lastDeltaSyncAt,
      let lastFull = calendar.lastFullSyncAt,
      calendar.syncWindowStart == windowStart,
      Date.now.timeIntervalSince(lastFull) < Constants.fullSyncInterval
    else {
      return .full
    }
    // Re-ask for a small overlap so a change landing between the server's clock
    // and ours cannot fall through the gap.
    return .delta(since: cursor.addingTimeInterval(-Constants.deltaSyncOverlap))
  }

  /// Records the outcome of an event fetch against a calendar's cursor.
  ///
  /// `completedAt` is captured *before* the request goes out, so anything
  /// modified while it was in flight is picked up by the next delta rather than
  /// skipped.
  func markEventsSynced(
    calendarId: String,
    mode: EventSyncMode,
    windowStart: Date,
    startedAt: Date
  ) {
    guard let calendar = get(calendarId: calendarId) else { return }
    calendar.lastSyncedAt = .now
    calendar.lastDeltaSyncAt = startedAt
    calendar.syncWindowStart = windowStart
    if case .full = mode {
      calendar.lastFullSyncAt = .now
    }
    try? modelContext.save()
    version &+= 1
  }

  /// Drops a calendar's incremental cursor, forcing a full read next cycle.
  /// Called when Google reports the cursor is no longer usable (410).
  func invalidateSyncCursor(calendarId: String) {
    guard let calendar = get(calendarId: calendarId) else { return }
    calendar.lastDeltaSyncAt = nil
    calendar.lastFullSyncAt = nil
    calendar.syncWindowStart = nil
    try? modelContext.save()
    version &+= 1
  }

  func logout(accountId: String) {
    let toRemove = calendars.filter { $0.accountId == accountId }
    for cal in toRemove { modelContext.delete(cal) }
    try? modelContext.save()
    calendars.removeAll { $0.accountId == accountId }
    colorPalettes[accountId] = nil
    version &+= 1
  }

  // MARK: - Sync

  /// Refreshes tokens then fetches every enabled account's calendar list in parallel.
  /// Returns `(accountId, calendarId)` pairs for every calendar present after sync.
  @discardableResult
  func sync() async -> [(String, String)] {
    let accountIds = await accounts.authenticated()
    guard !accountIds.isEmpty else { return [] }

    let fetched = await withTaskGroup(of: AccountSync?.self) { group in
      for accountId in accountIds {
        group.addTask { [weak self] in
          guard let self else { return nil }
          do {
            return try await self.fetch(accountId: accountId)
          } catch {
            // Records health only — the cached calendar list is left intact.
            await self.accounts.recordSyncFailure(accountId, error: error)
            return nil
          }
        }
      }
      var out: [AccountSync] = []
      for await result in group {
        if let result { out.append(result) }
      }
      return out
    }

    var results: [(String, String)] = []
    for result in fetched {
      let accountId = result.accountId
      applySync(accountId: accountId, entries: result.entries)
      if let colors = result.colors {
        colorPalettes[accountId] = ColorPalette(colors)
      }
      accounts.markSynced(accountId)
      accounts.recordSyncSuccess(accountId)
      for entry in result.entries { results.append((accountId, entry.id)) }
    }

    version &+= 1
    return results
  }

  /// One account's payload from a calendar-list sync cycle.
  nonisolated struct AccountSync: Sendable {
    let accountId: String
    let entries: [GCCalendarListEntry]
    /// `nil` when the palette fetch failed; the cached palette stays in force.
    let colors: GCColors?
  }

  /// Fetches an account's calendar list and color palette on a single token.
  ///
  /// The palette is authenticated per account, so it cannot be fetched once and
  /// shared. Its failure is swallowed rather than thrown: it must not cost the
  /// account its calendar list, and the cached palette — or the built-in
  /// defaults — covers the gap until the next cycle.
  func fetch(accountId: String) async throws -> AccountSync {
    try await accounts.withToken(for: accountId) { [api] token in
      // `async let` children do not inherit this actor, so they capture `api`
      // rather than `self`.
      async let entries = api.listCalendars(accessToken: token).items
      async let colors = try? api.listColors(accessToken: token)
      return AccountSync(
        accountId: accountId,
        entries: try await entries,
        colors: await colors
      )
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
