import Foundation
import Observation

/// Watches the clock and the event list and reports which alerts to show and
/// which to withdraw.
///
/// Re-evaluates whenever ``MinuteScheduler`` ticks, a sync changes the events,
/// or the alert style changes — the same re-arming `withObservationTracking`
/// loop `AppDelegate` uses for the refresh interval. Deciding is left to
/// ``MeetingAlertPolicy`` and remembering to ``MeetingAlertTracker``; how an
/// alert is shown is the caller's, through `onChange`.
@MainActor
final class MeetingAlertScheduler {

  private let eventManager: GoogleCalendarEventManager
  private let settings: UserSettings
  private let ticker: MinuteScheduler
  private let onChange: @MainActor (MeetingAlertChange) -> Void

  private var tracker = MeetingAlertTracker()
  private var isRunning = false
  /// The style the active alerts were shown in; `nil` before the first pass.
  private var lastStyle: MeetingAlertStyle?

  init(
    eventManager: GoogleCalendarEventManager,
    settings: UserSettings,
    ticker: MinuteScheduler,
    onChange: @escaping @MainActor (MeetingAlertChange) -> Void
  ) {
    self.eventManager = eventManager
    self.settings = settings
    self.ticker = ticker
    self.onChange = onChange
  }

  func start() {
    guard !isRunning else { return }
    isRunning = true
    observe()
  }

  func stop() {
    isRunning = false
  }

  /// Alerts raised and not yet expired or dismissed, oldest event first.
  var active: [MeetingAlert] { tracker.active }

  /// The user acted on the alerts showing — joined, opened or dismissed them.
  /// They stay raised, so they never come back.
  func dismissActive() {
    let dismissed = tracker.dismissActive()
    guard !dismissed.isEmpty else { return }
    onChange(MeetingAlertChange(expired: dismissed))
  }

  private func observe() {
    guard isRunning else { return }
    withObservationTracking {
      evaluate()
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.observe()
      }
    }
  }

  private func evaluate() {
    let now = ticker.now
    let entries = eventManager.entries(overlapping: MeetingAlertPolicy.window(around: now))
    let style = settings.meetingAlertStyle

    // One style at a time: a change withdraws what the old style is showing.
    // Those alerts stay raised, so they are not shown again in the new one.
    if style != lastStyle {
      lastStyle = style
      let withdrawn = tracker.dismissActive()
      if !withdrawn.isEmpty {
        onChange(MeetingAlertChange(expired: withdrawn))
      }
    }

    guard style != .off else { return }
    let change = tracker.update(entries: entries, now: now)
    guard !change.isEmpty else { return }
    onChange(change)
  }
}
