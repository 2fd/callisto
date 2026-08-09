import AppKit

/// Opening an entry in the browser. Lives on ``EventEntry`` because it already
/// carries both halves the URLs are built from: the event and the account whose
/// `authuser` index the link has to name.
extension EventEntry {
  /// Opens the event's meeting URL when it has one, else its Google Calendar page.
  func open() {
    if let meetURL = event.conferenceMeetURL(authuser: account.authuser) {
      NSWorkspace.shared.open(meetURL)
      dismissMenuBarPanel()
    } else {
      openInCalendar()
    }
  }

  /// Opens the event's Google Calendar page.
  func openInCalendar() {
    guard let url = event.calendarURL(authuser: account.authuser) else { return }
    NSWorkspace.shared.open(url)
    dismissMenuBarPanel()
  }

  /// The event's meeting URL, or `nil` when it has no conference link.
  var meetingURL: URL? {
    event.conferenceMeetURL(authuser: account.authuser)
  }
}
