import Foundation
import Observation

/// What the alert panel shows, derived from the alerts it was given.
///
/// Both moments can be due at once — one event starting while the user is
/// still in another and a third is five minutes out — so each gets its own
/// section rather than one hiding the other.
struct MeetingAlertContent {

  /// Events starting now, earliest first.
  let starting: [EventEntry]
  /// The event the user is in, for the heads-up section. `nil` when it is
  /// already listed under ``starting``.
  let current: EventEntry?
  /// Events starting soon while ``current`` is in progress, earliest first.
  let upNext: [EventEntry]

  /// `nil` when there is nothing to show.
  init?(alerts: [MeetingAlert]) {
    let starting = alerts.filter { $0.kind == .starting }
    let headsUp = alerts.filter { $0.kind == .headsUp }
    guard !starting.isEmpty || !headsUp.isEmpty else { return nil }

    self.starting = starting.map(\.entry)
    self.upNext = headsUp.map(\.entry)

    let first = headsUp.first
    let isListedAsStarting = starting.contains { $0.eventId == first?.currentId }
    self.current = isListedAsStarting ? nil : first?.current
  }
}

/// The alert panel's state. The panel's view is built once and hosted, so it
/// reads its content from here rather than taking it as a parameter.
@MainActor @Observable
final class MeetingAlertModel {
  var content: MeetingAlertContent?
}
