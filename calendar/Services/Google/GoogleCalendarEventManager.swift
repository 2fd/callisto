import Foundation
import SwiftData
import os

/// Top of the sync chain — owns events and constructs the account and calendar
/// managers it depends on.
///
/// ``AppDelegate`` holds only this instance and reaches through ``accounts``
/// and ``calendars`` to inject them into the SwiftUI environment.
@MainActor @Observable
final class GoogleCalendarEventManager {

  let accounts: GoogleAccountManager
  let calendars: GoogleCalendarManager
  private let modelContext: ModelContext
  private let api = GoogleCalendarAPI()

  private(set) var events: [GoogleCalendarEvent] = []
  private var version: UInt64 = 0

  var isEmpty: Bool {
    events.isEmpty
  }

  /// Whether a sync cycle is currently in progress.
  private(set) var isSyncing = false

  // MARK: - Init

  init(container: ModelContainer) {
    self.accounts = GoogleAccountManager(container: container)
    self.calendars = GoogleCalendarManager(
      accounts: accounts,
      container: container
    )
    self.modelContext = ModelContext(container)
    self.events =
      (try? modelContext.fetch(
        FetchDescriptor<GoogleCalendarEvent>(sortBy: [
          SortDescriptor(\.startDate)
        ])
      )) ?? []
  }

  // MARK: - Iteration

  /// Returns entries ordered chronologically by `startDate`, restricted to the
  /// `[yesterday, today + settings.showDaysAhead]` window. Each entry bundles the
  /// event with its calendar and account so callers need no further lookups.
  func iter(_ settings: UserSettings) -> [EventEntry] {
    _ = version

    let startOfToday = Calendar.current.startOfDay(for: .now)
    let yesterday = Calendar.current.date(
      byAdding: .day,
      value: -1,
      to: startOfToday
    )!
    let storageUpperBound = Calendar.current.date(
      byAdding: .day,
      value: 31,
      to: startOfToday
    )!
    let settingsUpperBound = Calendar.current.date(
      byAdding: .day,
      value: settings.showDaysAhead,
      to: startOfToday
    )!
    let upperBound = min(storageUpperBound, settingsUpperBound)

    let accountsById = Dictionary(
      uniqueKeysWithValues: accounts.iter().map { ($0.accountId, $0) }
    )
    let calendarsById = Dictionary(
      uniqueKeysWithValues: calendars.iter().map { ($0.calendarId, $0) }
    )
    let readableVisibleAccounts = Set(
      accountsById.values.filter { $0.isVisible && $0.canRead }.map(\.accountId)
    )
    let visibleCalendars = Set(
      calendarsById.values.filter(\.isVisible).map(\.calendarId)
    )

    var result: [EventEntry] = events.compactMap { event in
      guard event.startDate >= yesterday,
        event.startDate < upperBound,
        readableVisibleAccounts.contains(event.accountId),
        visibleCalendars.contains(event.calendarId),
        event.status != EventStatus.cancelled,
        event.endDate > startOfToday,
        let calendar = calendarsById[event.calendarId],
        calendar.accountId == event.accountId,
        let account = accountsById[event.accountId],
        account.canRead
      else { return nil }
      return EventEntry(event: event, calendar: calendar, account: account)
    }

    if !settings.showDeclinedEvents {
      result = result.filter { !$0.event.isDeclined }
    }
    return result
  }

  /// Returns ``EventDay`` entries grouped by day. When `settings.showEmptyDays`
  /// is on, emits a placeholder entry for every day in the window with no events.
  func iterByDays(_ settings: UserSettings) -> [EventDay] {
    _ = version

    let dayEntries = iter(settings)
    let cal = Calendar.current
    let startOfToday = cal.startOfDay(for: .now)

    var dayMap: [Date: [EventEntry]] = [:]
    for entry in dayEntries {
      let anchor =
        entry.event.startDate < startOfToday
        ? startOfToday : entry.event.startDate
      let day = cal.startOfDay(for: anchor)
      dayMap[day, default: []].append(entry)
    }

    if settings.showEmptyDays {
      for offset in 0..<settings.showDaysAhead {
        if let day = cal.date(byAdding: .day, value: offset, to: startOfToday) {
          dayMap[day, default: []] = dayMap[day] ?? []
        }
      }
    }

    return dayMap.keys.sorted().map { day in
      let sorted = (dayMap[day] ?? []).sorted {
        $0.event.startDate < $1.event.startDate
      }
      return EventDay(day: day, entries: sorted)
    }
  }

  /// The next upcoming, non-declined, non-cancelled event across visible
  /// accounts and visible calendars.
  func next() -> GoogleCalendarEvent? {
    _ = version
    let now = Date.now
    let readableVisibleAccounts = Set(
      accounts.iter().filter { $0.isVisible && $0.canRead }.map(\.accountId)
    )
    let calendarsById = Dictionary(
      uniqueKeysWithValues: calendars.iter().map { ($0.calendarId, $0) }
    )
    let visibleCalendars = Set(
      calendarsById.values.filter(\.isVisible).map(\.calendarId)
    )

    let upcoming = events.filter { event in
      event.endDate > now
        && !event.isDeclined
        && event.status != EventStatus.cancelled
        && readableVisibleAccounts.contains(event.accountId)
        && visibleCalendars.contains(event.calendarId)
        && calendarsById[event.calendarId]?.accountId == event.accountId
    }.sorted { $0.startDate < $1.startDate }

    return upcoming.first { !$0.isAllDay } ?? upcoming.first
  }

  // MARK: - Sync

  /// Full sync: refresh tokens, sync calendar lists, then fetch events for
  /// every `(account, calendar)` pair within `[today, today + 31 days]` in parallel.
  func sync() async {
    if isSyncing {
      return
    }

    isSyncing = true
    defer { isSyncing = false }

    let pairs = await calendars.sync()
    guard !pairs.isEmpty else { return }

    let cal = Calendar.current
    let timeMin = cal.startOfDay(for: .now)
    let timeMax = cal.date(byAdding: .day, value: 31, to: timeMin)!

    let fetched = await withTaskGroup(
      of: (String, String, [GCEvent])?.self
    ) { group in
      for (accountId, calendarId) in pairs {
        group.addTask { [weak self] in
          guard let self else { return nil }
          do {
            let events = try await self.fetch(
              accountId: accountId,
              calendarId: calendarId,
              timeMin: timeMin,
              timeMax: timeMax
            )
            return (accountId, calendarId, events)
          } catch {
            await self.handleReadFailure(accountId: accountId, error: error)
            await Logger.shared.error(
              "Event fetch failed \(accountId, privacy: .public)/\(calendarId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
          }
        }
      }
      var out: [(String, String, [GCEvent])] = []
      for await result in group {
        if let result { out.append(result) }
      }
      return out
    }

    for (accountId, calendarId, events) in fetched {
      applySync(accountId: accountId, calendarId: calendarId, fetched: events)
      calendars.accounts.markSynced(calendarId)
      accounts.markSynced(accountId)
    }

    resortEvents()
    version &+= 1
  }

  /// Fetches events for a single calendar.
  func fetch(
    accountId: String,
    calendarId: String,
    timeMin: Date,
    timeMax: Date
  ) async throws -> [GCEvent] {
    let token = try await accounts.token(for: accountId)
    let response = try await api.listEvents(
      calendarId: calendarId,
      accessToken: token,
      timeMin: timeMin,
      timeMax: timeMax
    )
    return response.items
  }

  // MARK: - Mutations

  /// Scope of a mutation on a recurring event.
  enum RecurringScope: Sendable {
    /// Apply to the single instance being acted upon.
    case thisEvent
    /// Apply to this instance and every future instance in the series.
    case thisAndFollowing
  }

  /// Updates the current user's RSVP response on an event.
  ///
  /// `scope` is honored only for recurring events; non-recurring events are
  /// always mutated as a single event.
  func setSelfResponse(
    _ event: GoogleCalendarEvent,
    to status: String,
    scope: RecurringScope = .thisEvent
  ) async throws {
    guard let account = accounts.get(event.accountId),
      account.canWrite
    else {
      throw MutationError.missingWriteScope
    }
    let selfEmail = event.selfAttendee?.email ?? account.email
    guard !selfEmail.isEmpty else {
      throw MutationError.notAnAttendee
    }

    let token = try await accounts.token(for: event.accountId)
    let targetId: String
    switch scope {
    case .thisEvent:
      targetId = event.eventId
    case .thisAndFollowing:
      guard let parentId = event.recurringEventId else {
        targetId = event.eventId
        break
      }
      targetId = parentId
    }

    let parentEvent: GCEvent?
    if targetId == event.eventId {
      parentEvent = nil
    } else {
      parentEvent = try await api.getEvent(
        calendarId: event.calendarId,
        eventId: targetId,
        accessToken: token
      )
    }

    let body = rsvpBody(
      forEvent: event,
      parent: parentEvent,
      selfEmail: selfEmail,
      newStatus: status
    )

    let updated = try await api.patchEvent(
      calendarId: event.calendarId,
      eventId: targetId,
      accessToken: token,
      body: body,
      sendUpdates: .all
    )

    if updated.id == event.eventId {
      applyEventUpdate(
        accountId: event.accountId,
        calendarId: event.calendarId,
        from: updated
      )
    } else {
      Task { await sync() }
    }
    version &+= 1
  }

  /// Deletes an event the user organizes (or can delete).
  ///
  /// - `scope == .thisEvent`: deletes a single instance (or the event itself
  ///   when not recurring).
  /// - `scope == .thisAndFollowing`: rewrites the parent series' `RRULE`
  ///   `UNTIL` so every instance from this one onward disappears.
  func deleteEvent(
    _ event: GoogleCalendarEvent,
    scope: RecurringScope = .thisEvent
  ) async throws {
    guard let account = accounts.get(event.accountId),
      account.canWrite
    else {
      throw MutationError.missingWriteScope
    }

    let token = try await accounts.token(for: event.accountId)

    switch scope {
    case .thisEvent:
      try await api.deleteEvent(
        calendarId: event.calendarId,
        eventId: event.eventId,
        accessToken: token,
        sendUpdates: .all
      )
      removeLocal(event: event)

    case .thisAndFollowing:
      guard let parentId = event.recurringEventId else {
        try await api.deleteEvent(
          calendarId: event.calendarId,
          eventId: event.eventId,
          accessToken: token,
          sendUpdates: .all
        )
        removeLocal(event: event)
        return
      }
      try await truncateParentSeries(
        parentId: parentId,
        calendarId: event.calendarId,
        accessToken: token,
        instanceStart: event.startDate
      )
      removeLocalFollowing(
        accountId: event.accountId,
        calendarId: event.calendarId,
        parentId: parentId,
        from: event.startDate
      )
    }

    try? modelContext.save()
    version &+= 1
    Task { await sync() }
  }

  /// Removes the event from the current user's view when they're not the
  /// organizer by declining the invitation (Google's canonical "Remove from
  /// my calendar" path for guests).
  func deleteForMe(
    _ event: GoogleCalendarEvent,
    scope: RecurringScope = .thisEvent
  ) async throws {
    try await setSelfResponse(event, to: EventStatus.declined, scope: scope)
    // Honor "show declined events = false" by hiding locally regardless.
    removeLocal(event: event)
    try? modelContext.save()
    version &+= 1
  }

  /// Updates account permission state after a failed event mutation.
  func handleMutationFailure(_ event: GoogleCalendarEvent, error: Error) {
    guard error.isPermissionDenied else { return }
    accounts.markWritePermissionDenied(event.accountId)
  }

  // MARK: - Mutation support

  nonisolated enum MutationError: LocalizedError {
    case missingWriteScope
    case notAnAttendee
    case invalidRecurrence

    var errorDescription: String? {
      switch self {
      case .missingWriteScope:
        "This account doesn't have permission to edit events."
      case .notAnAttendee:
        "You're not an attendee of this event."
      case .invalidRecurrence:
        "Couldn't parse the recurrence rule of this event."
      }
    }
  }

  /// Builds a PATCH body that updates only the self attendee's response.
  ///
  /// When `parent` is provided (series-level mutation) we preserve the full
  /// attendees array with the self entry's status swapped. For instance-level
  /// PATCHes on events where attendees aren't yet materialized client-side,
  /// we fall back to a minimal `[selfAttendee]` body which Google interprets
  /// as "update this attendee, leave others untouched".
  private func rsvpBody(
    forEvent event: GoogleCalendarEvent,
    parent: GCEvent?,
    selfEmail: String,
    newStatus: String
  ) -> GCEventWrite {
    if let parent, let attendees = parent.attendees {
      let rewritten = attendees.map { att -> GCAttendee in
        guard att.email?.caseInsensitiveCompare(selfEmail) == .orderedSame
          || att.`self` == true
        else { return att }
        return GCAttendee(
          id: att.id,
          email: att.email,
          displayName: att.displayName,
          organizer: att.organizer,
          `self`: att.`self`,
          resource: att.resource,
          optional: att.`optional`,
          responseStatus: newStatus,
          comment: att.comment,
          additionalGuests: att.additionalGuests
        )
      }
      return GCEventWrite(attendees: rewritten)
    }

    let selfEntry = GCAttendee.write(email: selfEmail, responseStatus: newStatus)
    let others = event.attendees
      .filter {
        !($0.isSelf
          || $0.email.caseInsensitiveCompare(selfEmail) == .orderedSame)
      }
      .map { local in
        GCAttendee.write(
          email: local.email,
          responseStatus: local.responseStatus,
          displayName: local.displayName,
          optional: local.isOptional ? true : nil,
          comment: local.comment,
          additionalGuests: local.additionalGuests > 0
            ? local.additionalGuests : nil
        )
      }
    return GCEventWrite(attendees: [selfEntry] + others)
  }

  /// Truncates a recurring series by rewriting its first `RRULE` with an
  /// `UNTIL` value one second before `instanceStart`. `COUNT` is stripped
  /// since `UNTIL` and `COUNT` are mutually exclusive per RFC 5545.
  private func truncateParentSeries(
    parentId: String,
    calendarId: String,
    accessToken: String,
    instanceStart: Date
  ) async throws {
    let parent = try await api.getEvent(
      calendarId: calendarId,
      eventId: parentId,
      accessToken: accessToken
    )
    guard let recurrence = parent.recurrence,
      let index = recurrence.firstIndex(where: { $0.hasPrefix("RRULE:") })
    else {
      throw MutationError.invalidRecurrence
    }
    let rewritten = Self.rrule(recurrence[index], withUntilBefore: instanceStart)
    var newRecurrence = recurrence
    newRecurrence[index] = rewritten
    let body = GCEventWrite(recurrence: newRecurrence)
    _ = try await api.patchEvent(
      calendarId: calendarId,
      eventId: parentId,
      accessToken: accessToken,
      body: body,
      sendUpdates: .all
    )
  }

  /// Rewrites an RRULE line to set `UNTIL` to one second before `boundary`
  /// (UTC, iCalendar basic format `yyyyMMdd'T'HHmmss'Z'`). Any existing
  /// `UNTIL` or `COUNT` value is stripped.
  static func rrule(_ line: String, withUntilBefore boundary: Date) -> String {
    let until = Calendar.current.date(byAdding: .second, value: -1, to: boundary) ?? boundary
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    let untilStr = fmt.string(from: until)

    let prefix = "RRULE:"
    guard line.hasPrefix(prefix) else { return line }
    let payload = String(line.dropFirst(prefix.count))
    var parts =
      payload.split(separator: ";", omittingEmptySubsequences: true)
      .map(String.init)
    parts.removeAll { $0.hasPrefix("UNTIL=") || $0.hasPrefix("COUNT=") }
    parts.append("UNTIL=\(untilStr)")
    return prefix + parts.joined(separator: ";")
  }

  private func applyEventUpdate(
    accountId: String,
    calendarId: String,
    from gc: GCEvent
  ) {
    let compositeId = "\(calendarId)/\(gc.id)"
    if let existing = events.first(where: { $0.compositeId == compositeId }) {
      existing.update(from: gc)
      syncAttendees(for: existing, from: gc.attendees)
      syncAttachments(for: existing, from: gc.attachments)
      syncReminders(for: existing, from: gc.reminders)
    } else if let inserted = GoogleCalendarEvent(
      from: gc,
      accountId: accountId,
      calendarId: calendarId
    ) {
      modelContext.insert(inserted)
      events.append(inserted)
      syncAttendees(for: inserted, from: gc.attendees)
      syncAttachments(for: inserted, from: gc.attachments)
      syncReminders(for: inserted, from: gc.reminders)
    }
    try? modelContext.save()
  }

  private func removeLocal(event: GoogleCalendarEvent) {
    modelContext.delete(event)
    events.removeAll { $0 === event }
  }

  private func removeLocalFollowing(
    accountId: String,
    calendarId: String,
    parentId: String,
    from boundary: Date
  ) {
    let stale = events.filter {
      $0.accountId == accountId && $0.calendarId == calendarId
        && $0.recurringEventId == parentId && $0.startDate >= boundary
    }
    for event in stale { modelContext.delete(event) }
    events.removeAll { stale.contains($0) }
  }

  /// Deletes events whose end date is before yesterday.
  func prune() {
    let yesterday = Calendar.current.date(
      byAdding: .day,
      value: -1,
      to: Calendar.current.startOfDay(for: .now)
    )!

    let stale = events.filter { $0.endDate < yesterday }
    guard !stale.isEmpty else { return }

    Logger.shared.debug("Pruning \(stale.count) stale event(s)")
    for event in stale {
      modelContext.delete(event)
    }
    try? modelContext.save()
    events.removeAll { $0.endDate < yesterday }
    version &+= 1
  }

  /// Removes every event belonging to an account (called on logout).
  func logout(accountId: String) {
    let toRemove = events.filter { $0.accountId == accountId }
    for event in toRemove { modelContext.delete(event) }
    try? modelContext.save()
    events.removeAll { $0.accountId == accountId }
    version &+= 1
  }

  // MARK: - Private

  private func handleReadFailure(accountId: String, error: Error) {
    guard error.isPermissionDenied else { return }
    accounts.markReadPermissionDenied(accountId)
    logout(accountId: accountId)
  }

  private func applySync(
    accountId: String,
    calendarId: String,
    fetched: [GCEvent]
  ) {
    let compositeIds = Set(fetched.map { "\(calendarId)/\($0.id)" })
    let existing = events.filter {
      $0.calendarId == calendarId && $0.accountId == accountId
    }
    let byId = Dictionary(
      uniqueKeysWithValues: existing.map { ($0.compositeId, $0) }
    )

    for gc in fetched {
      let id = "\(calendarId)/\(gc.id)"
      if let event = byId[id] {
        event.update(from: gc)
        syncAttendees(for: event, from: gc.attendees)
        syncAttachments(for: event, from: gc.attachments)
        syncReminders(for: event, from: gc.reminders)
      } else if let event = GoogleCalendarEvent(
        from: gc,
        accountId: accountId,
        calendarId: calendarId
      ) {
        modelContext.insert(event)
        events.append(event)
        syncAttendees(for: event, from: gc.attendees)
        syncAttachments(for: event, from: gc.attachments)
        syncReminders(for: event, from: gc.reminders)
      }
    }

    let stale = existing.filter { !compositeIds.contains($0.compositeId) }
    for event in stale { modelContext.delete(event) }
    events.removeAll { stale.contains($0) }

    try? modelContext.save()
  }

  private func syncAttendees(
    for event: GoogleCalendarEvent,
    from gcAttendees: [GCAttendee]?
  ) {
    for existing in event.attendees { modelContext.delete(existing) }
    for gc in gcAttendees ?? [] {
      if let attendee = EventAttendee(from: gc) {
        attendee.event = event
        modelContext.insert(attendee)
      }
    }
  }

  private func syncAttachments(
    for event: GoogleCalendarEvent,
    from gcAttachments: [GCAttachment]?
  ) {
    for existing in event.attachments { modelContext.delete(existing) }
    for gc in gcAttachments ?? [] {
      if let attachment = EventAttachment(from: gc) {
        attachment.event = event
        modelContext.insert(attachment)
      }
    }
  }

  private func syncReminders(
    for event: GoogleCalendarEvent,
    from gcReminders: GCReminders?
  ) {
    for existing in event.reminders { modelContext.delete(existing) }
    for gc in gcReminders?.overrides ?? [] {
      if let reminder = EventReminder(from: gc) {
        reminder.event = event
        modelContext.insert(reminder)
      }
    }
  }

  private func resortEvents() {
    events.sort { $0.startDate < $1.startDate }
  }
}
