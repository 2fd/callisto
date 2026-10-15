import Foundation

/// Which moment of an event an alert is for.
enum MeetingAlertKind: String, Sendable {
  /// A few minutes early, raised only while another event is in progress so the
  /// user has time to wrap it up.
  case headsUp
  /// The moment the event starts.
  case starting
}

/// One alert the user should see: an event, and which of its moments is due.
struct MeetingAlert: Identifiable {
  let entry: EventEntry
  let kind: MeetingAlertKind
  /// The event in progress when a heads-up was raised; `nil` for `.starting`.
  let current: EventEntry?

  /// Identity copied out of the entries when the alert is made. The events are
  /// live SwiftData models: a sync can reschedule or delete them under us, and
  /// an alert has to be matched and withdrawn without reading one that is gone.
  let eventId: String
  let currentId: String?
  let startDate: Date
  let id: String

  init(entry: EventEntry, kind: MeetingAlertKind, current: EventEntry? = nil) {
    self.entry = entry
    self.kind = kind
    self.current = current
    self.eventId = entry.event.compositeId
    self.currentId = current?.event.compositeId
    self.startDate = entry.event.startDate
    self.id = MeetingAlertPolicy.key(eventId: eventId, kind: kind, start: startDate)
  }
}

/// When to alert, as pure functions of the entries and the time.
///
/// - With nothing else in progress, an event is announced once, when it starts.
/// - While another event is in progress, it is also announced
///   ``Constants/meetingHeadsUpLead`` early.
///
/// Every moment stays due for ``Constants/meetingAlertGrace``, so a late tick
/// or a wake from sleep still raises it but a stale one never is.
enum MeetingAlertPolicy {

  /// Identifies an alert across ticks. Carries the start, so an event moved to
  /// a new time is announced again.
  static func key(eventId: String, kind: MeetingAlertKind, start: Date) -> String {
    "\(eventId)@\(Int(start.timeIntervalSince1970))#\(kind.rawValue)"
  }

  /// How far around `now` an event has to reach to matter: anything underway,
  /// and anything whose heads-up or start is due.
  static func window(around now: Date) -> DateInterval {
    DateInterval(
      start: now.addingTimeInterval(-Constants.meetingAlertGrace),
      end: now.addingTimeInterval(Constants.meetingHeadsUpLead + Constants.meetingAlertGrace)
    )
  }

  /// The alerts due at `now` that are not in `alerted` yet.
  static func due(
    entries: [EventEntry],
    now: Date,
    alerted: Set<String> = []
  ) -> [MeetingAlert] {
    let candidates = entries.filter(\.event.isAlertable)

    return candidates.compactMap { entry -> MeetingAlert? in
      let start = entry.event.startDate
      let alert: MeetingAlert

      if isWithinGrace(now, of: start) {
        // An event that is already over is not announced, however late the tick.
        guard now < alertEnd(of: entry.event) else { return nil }
        alert = MeetingAlert(entry: entry, kind: .starting)
      } else if isWithinGrace(now, of: start.addingTimeInterval(-Constants.meetingHeadsUpLead)),
        let busy = inProgress(candidates, at: now, excluding: entry)
      {
        alert = MeetingAlert(entry: entry, kind: .headsUp, current: busy)
      } else {
        return nil
      }

      return alerted.contains(alert.id) ? nil : alert
    }
    .sorted { $0.startDate < $1.startDate }
  }

  /// Whether `alert` no longer applies: its event ended, was rescheduled,
  /// declined or removed, or — for a heads-up — has started.
  static func isExpired(_ alert: MeetingAlert, in entries: [EventEntry], now: Date) -> Bool {
    guard let event = entries.first(where: { $0.event.compositeId == alert.eventId })?.event,
      event.isAlertable,
      event.startDate == alert.startDate,
      alertEnd(of: event) > now
    else { return true }

    return alert.kind == .headsUp && now >= alert.startDate
  }

  /// `alert` rebuilt from the current `entries`, so it never holds a model a
  /// sync has replaced, and a heads-up names whatever the user is in *now* —
  /// or nothing, once that event ended, was declined or was removed. Call only
  /// for an alert that is not expired.
  static func refreshed(_ alert: MeetingAlert, in entries: [EventEntry], now: Date) -> MeetingAlert {
    guard let entry = entries.first(where: { $0.event.compositeId == alert.eventId }) else {
      return alert
    }
    switch alert.kind {
    case .starting:
      return MeetingAlert(entry: entry, kind: .starting)
    case .headsUp:
      let candidates = entries.filter(\.event.isAlertable)
      let current = inProgress(candidates, at: now, excluding: entry)
      return MeetingAlert(entry: entry, kind: .headsUp, current: current)
    }
  }

  // MARK: - Helpers

  private static func isWithinGrace(_ now: Date, of moment: Date) -> Bool {
    moment <= now && now < moment.addingTimeInterval(Constants.meetingAlertGrace)
  }

  /// When an alert for `event` stops applying: its end, or — for an event with
  /// no duration, a deadline or a reminder — the end of its grace.
  private static func alertEnd(of event: GoogleCalendarEvent) -> Date {
    event.endDate > event.startDate
      ? event.endDate
      : event.startDate.addingTimeInterval(Constants.meetingAlertGrace)
  }

  /// The event the user is in at `now`, other than `entry` — the one that ends
  /// first when several overlap, since that is the one they are wrapping up.
  private static func inProgress(
    _ candidates: [EventEntry],
    at now: Date,
    excluding entry: EventEntry
  ) -> EventEntry? {
    candidates
      .filter { $0.id != entry.id && $0.event.isUnderway(at: now) }
      .min { $0.event.endDate < $1.event.endDate }
  }
}
