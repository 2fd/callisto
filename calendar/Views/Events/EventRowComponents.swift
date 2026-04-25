import SwiftUI

/// Icon indicating the type of conference link (Zoom, Google Meet, or generic video).
struct ConferenceIconView: View {
  let event: GoogleCalendarEvent

  var body: some View {
    Image(systemName: "video.fill")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .foregroundStyle(Color(hex: event.conferenceColor))
      .frame(width: 14, height: 14)
      .help("Has meeting link")
  }
}

/// Action buttons displayed alongside an event: calendar link, location pin, and attendee count.
struct EventActionButtons: View {
  let event: GoogleCalendarEvent

  var body: some View {

    if let location = event.location, !location.isEmpty {
      Image(systemName: "mappin")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .help(location)
    }

    if event.conferenceMeetURL != nil {
      ConferenceIconView(event: event)
    }
  }
}

/// Action buttons displayed alongside an event: calendar link, location pin, and attendee count.
struct OpenCalendarActionButton: View {
  let event: GoogleCalendarEvent
  let account: GoogleAccount

  var body: some View {
    Button {
      openCalendarLink(for: event, account: account)
    } label: {
      Image(systemName: "arrow.up.forward.app")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help("Open in Google Calendar")
  }
}

/// Opens the event's meet URL if available, otherwise falls back to the Google Calendar link.
func openEventLink(_ event: GoogleCalendarEvent, account: GoogleAccount) {
  if let meetURL = event.conferenceMeetURL(authuser: account.authuser) {
    NSWorkspace.shared.open(meetURL)
    NSApp.keyWindow?.close()
  } else if let url = event.calendarURL(authuser: account.authuser) {
    NSWorkspace.shared.open(url)
    NSApp.keyWindow?.close()
  }
}

/// Opens the event's Google Calendar link.
func openCalendarLink(for event: GoogleCalendarEvent, account: GoogleAccount) {
  if let url = event.calendarURL(authuser: account.authuser) {
    NSWorkspace.shared.open(url)
    NSApp.keyWindow?.close()
  }
}

/// A view modifier that adds a hover effect with a rounded background and pointer cursor.
struct EventHoverEffect: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(
            isHovered && isEnabled ? Color.primary.opacity(0.06) : Color.clear
          )
      )
      .onHover { hovering in
        isHovered = hovering
      }
  }
}

extension View {
  /// Applies a hover effect with a subtle background highlight and pointer cursor.
  func eventHoverEffect() -> some View {
    modifier(EventHoverEffect())
  }
}
