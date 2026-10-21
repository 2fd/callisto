import AppKit

/// Opening an entry's links. Lives on ``EventEntry`` because it already
/// carries both halves the URLs are built from: the event and the account whose
/// `authuser` index the link has to name.
extension EventEntry {
  /// Opens the event's meeting when it has one, else its Google Calendar page.
  func open() {
    if meetingURL != nil {
      openMeeting()
    } else {
      openInCalendar()
    }
  }

  /// Opens the event's meeting: in the Zoom app when the link is a Zoom
  /// meeting and the app is installed, else in the browser.
  func openMeeting() {
    guard let url = meetingURL else { return }
    if !Self.openInZoomApp(url) {
      NSWorkspace.shared.open(url)
    }
    dismissMenuBarPanel(actingOn: event)
  }

  /// `false` when `url` is not a Zoom meeting link, no app handles `zoomus://`,
  /// or Launch Services refuses to open it.
  private static func openInZoomApp(_ url: URL) -> Bool {
    guard let appURL = url.zoomAppURL,
      NSWorkspace.shared.urlForApplication(toOpen: appURL) != nil
    else { return false }
    return NSWorkspace.shared.open(appURL)
  }

  /// Opens the event's Google Calendar page.
  func openInCalendar() {
    guard let url = event.calendarURL(authuser: account.authuser) else { return }
    NSWorkspace.shared.open(url)
    dismissMenuBarPanel(actingOn: event)
  }

  /// The event's meeting URL, or `nil` when it has no conference link.
  var meetingURL: URL? {
    event.conferenceMeetURL(authuser: account.authuser)
  }
}
