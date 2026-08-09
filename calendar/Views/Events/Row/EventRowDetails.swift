import SwiftUI

/// What an event carries besides its title and its hours: where it is, and how
/// to join it.
///
/// Both inherit the row's foreground rather than setting their own, so they dim
/// with it — see ``EventRow``'s use of ``EventRowStyle/detail``.
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
      if let provider = event.conferenceProvider {
        ConferenceLabelView(provider: provider)
      } else {
        ConferenceIconView(event: event, branded: false)
      }
    }
  }
}
