import AppKit
import Observation
import UserNotifications
import os

/// Delivers ``MeetingAlert``s as native notifications.
///
/// Clicking a notification does what tapping its row does — ``EventEntry/open()``
/// joins the meeting, or opens the event in Google Calendar when there is none.
/// Only an event that has started offers a Join button: before then there is
/// nothing to join yet.
///
/// Local notifications need no entitlement in the sandbox, only the user's
/// permission, which is asked for when this style is chosen. The permission is
/// published as ``authorizationStatus`` so Settings can say when it was refused.
@MainActor @Observable
final class MeetingNotifier: NSObject, UNUserNotificationCenterDelegate {

  /// Scoped to this app's notifications already, so no bundle prefix.
  nonisolated private enum Identifier {
    static let startingCategory = "meeting.starting"
    static let joinAction = "meeting.join"
    static let eventKey = "eventId"
  }

  /// Whether the user allowed notifications, as last read from the system.
  /// Re-read after asking and whenever the app becomes active, since the user
  /// changes it in System Settings.
  private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

  @ObservationIgnored private let center = UNUserNotificationCenter.current()
  @ObservationIgnored private var activationObserver: (any NSObjectProtocol)?
  /// Alerts handed to ``post(_:)`` and not added yet; ``withdraw(_:)`` takes
  /// them back out.
  @ObservationIgnored private var inFlight: Set<String> = []

  /// Looks up the entry a clicked notification is for, by `compositeId`.
  @ObservationIgnored private let resolve: @MainActor (String) -> EventEntry?

  init(resolve: @escaping @MainActor (String) -> EventEntry?) {
    self.resolve = resolve
    super.init()
  }

  /// Becomes the center's delegate. Call before launch finishes, so a click on
  /// a notification that launched the app is not missed.
  ///
  /// Also clears notifications left by a previous run: alerts are remembered
  /// in memory only, so nothing would ever withdraw them once their event ends.
  func register() {
    center.delegate = self
    center.removeAllDeliveredNotifications()

    let join = UNNotificationAction(
      identifier: Identifier.joinAction,
      title: String(localized: "Join")
    )
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Identifier.startingCategory,
        actions: [join],
        intentIdentifiers: []
      )
    ])

    activationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshAuthorizationStatus() }
    }
    refreshAuthorizationStatus()
  }

  func requestAuthorization() {
    Task {
      do {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        Logger.shared.info("Notification permission granted: \(granted, privacy: .public)")
      } catch {
        Logger.shared.error(
          "Notification permission request failed: \(error.localizedDescription, privacy: .public)"
        )
      }
      await readAuthorizationStatus()
    }
  }

  func refreshAuthorizationStatus() {
    Task { await readAuthorizationStatus() }
  }

  private func readAuthorizationStatus() async {
    authorizationStatus = await center.notificationSettings().authorizationStatus
  }

  func post(_ alert: MeetingAlert) {
    inFlight.insert(alert.id)
    Task {
      // An alert due before the permission prompt was answered would fail and
      // never be retried, so settle the permission first.
      if await center.notificationSettings().authorizationStatus == .notDetermined {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await readAuthorizationStatus()
      }

      // The prompt can sit unanswered for hours. If the alert was withdrawn
      // meanwhile — its event ended, or the style changed — it must not land.
      guard inFlight.remove(alert.id) != nil else { return }

      let request = UNNotificationRequest(
        identifier: alert.id,
        content: Self.content(for: alert),
        trigger: nil
      )
      do {
        try await center.add(request)
      } catch {
        Logger.shared.error(
          "Could not post a meeting notification: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }

  /// Removes notifications that no longer apply — their event ended, moved or
  /// was declined — from Notification Center, including any still waiting to
  /// be posted.
  func withdraw(_ alerts: [MeetingAlert]) {
    guard !alerts.isEmpty else { return }
    let ids = alerts.map(\.id)
    inFlight.subtract(ids)
    center.removeDeliveredNotifications(withIdentifiers: ids)
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }

  /// Built when the notification is actually added, so a heads-up says how
  /// long is really left.
  private static func content(for alert: MeetingAlert) -> UNMutableNotificationContent {
    let event = alert.entry.event
    let content = UNMutableNotificationContent()
    content.title = event.summary
    content.subtitle = hours(of: event)
    content.body = body(for: alert)
    content.sound = .default
    content.threadIdentifier = alert.eventId
    content.userInfo = [Identifier.eventKey: alert.eventId]
    if alert.kind == .starting, alert.entry.meetingURL != nil {
      content.categoryIdentifier = Identifier.startingCategory
    }
    return content
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// An accessory app is often the active one — the panel or settings may have
  /// focus — and without this the banner would be swallowed. `.list` keeps it
  /// in Notification Center after the banner goes.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let action = response.actionIdentifier
    guard action == UNNotificationDefaultActionIdentifier || action == Identifier.joinAction,
      let id = response.notification.request.content.userInfo[Identifier.eventKey] as? String
    else { return }

    await MainActor.run {
      guard let entry = resolve(id) else {
        Logger.shared.info("Clicked a notification for an event no longer in the window")
        return
      }
      entry.open()
    }
  }

  // MARK: - Copy

  private static func body(for alert: MeetingAlert) -> String {
    switch alert.kind {
    case .starting:
      return String(localized: "Starting now")
    case .headsUp:
      // From the actual time left: a late tick or a wake can post it after the
      // five-minute mark.
      let left = alert.startDate.timeIntervalSince(.now)
      let minutes = max(1, Int((left / 60).rounded(.up)))
      guard let current = alert.current else {
        return String(localized: "Starts in \(minutes) min")
      }
      return String(localized: "Starts in \(minutes) min · \(current.event.summary) is still on")
    }
  }

  private static func hours(of event: GoogleCalendarEvent) -> String {
    (event.startDate..<max(event.startDate, event.endDate))
      .formatted(date: .omitted, time: .shortened)
  }
}
