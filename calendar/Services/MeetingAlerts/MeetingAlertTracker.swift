import Foundation

/// What changed in one ``MeetingAlertTracker/update(entries:now:)``.
struct MeetingAlertChange {
  /// Alerts raised now, to be shown.
  var delivered: [MeetingAlert] = []
  /// Shown alerts that no longer apply, to be withdrawn.
  var expired: [MeetingAlert] = []
  /// Every alert still showing after the change, oldest event first.
  var active: [MeetingAlert] = []
  /// An alert kept from before now names a different event in progress.
  var currentChanged = false

  var isEmpty: Bool { delivered.isEmpty && expired.isEmpty && !currentChanged }
}

/// Remembers which alerts were raised and which are still showing, so each one
/// is raised exactly once and withdrawn when it stops applying.
///
/// A value type with no clock and no side effects; ``MeetingAlertScheduler``
/// feeds it ticks and acts on the ``MeetingAlertChange`` it returns.
struct MeetingAlertTracker {

  /// Every alert raised, keyed by ``MeetingAlert/id``, with the start it was
  /// for so old keys can be pruned. Held for a day after that start so an
  /// alert is never raised twice, even across a reschedule and back.
  private(set) var raised: [String: Date] = [:]

  /// Raised alerts still on screen, until they expire or are dismissed.
  private(set) var active: [MeetingAlert] = []

  mutating func update(entries: [EventEntry], now: Date) -> MeetingAlertChange {
    var change = MeetingAlertChange()

    let (expired, stillValid) = active.partitioned {
      MeetingAlertPolicy.isExpired($0, in: entries, now: now)
    }
    change.expired = expired

    let kept = stillValid.map { MeetingAlertPolicy.refreshed($0, in: entries, now: now) }
    change.currentChanged = zip(stillValid, kept).contains { $0.currentId != $1.currentId }

    let delivered = MeetingAlertPolicy.due(
      entries: entries,
      now: now,
      alerted: Set(raised.keys)
    )
    for alert in delivered {
      raised[alert.id] = alert.startDate
    }
    change.delivered = delivered

    active = (kept + delivered).sorted { $0.startDate < $1.startDate }
    change.active = active

    raised = raised.filter { now.timeIntervalSince($0.value) < Constants.meetingAlertRetention }
    return change
  }

  /// The user acted on what was showing — joined, opened or dismissed it. The
  /// alerts stay raised, so they never come back.
  mutating func dismissActive() -> [MeetingAlert] {
    defer { active = [] }
    return active
  }
}

private extension Array {
  /// Splits into the elements matching `predicate` and the rest, in order.
  func partitioned(by predicate: (Element) -> Bool) -> ([Element], [Element]) {
    var matching: [Element] = []
    var rest: [Element] = []
    for element in self {
      if predicate(element) { matching.append(element) } else { rest.append(element) }
    }
    return (matching, rest)
  }
}
