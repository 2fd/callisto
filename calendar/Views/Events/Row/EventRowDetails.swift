import SwiftUI

/// What an event carries besides its title and its hours: where it is, and how
/// to join it.
///
/// Location uses secondary text; the video icon preserves its provider color.
struct EventRowDetails: View {
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
