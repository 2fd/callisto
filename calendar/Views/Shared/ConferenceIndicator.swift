import SwiftUI

/// Icon indicating the type of conference link (Zoom, Google Meet, or generic video).
struct ConferenceIconView: View {
  let event: GoogleCalendarEvent
  /// Draw in the provider's brand color. The menu bar needs it — colour is the
  /// only thing distinguishing providers there — while a row inherits the
  /// foreground of the event it sits on.
  var branded: Bool = true

  var body: some View {
    Image(systemName: "video.fill")
      .resizable()
      .aspectRatio(contentMode: .fit)
      .foregroundStyle(
        branded
          ? AnyShapeStyle(Color(hex: event.conferenceColor))
          : AnyShapeStyle(.foreground)
      )
      .frame(width: 14, height: 14)
      .help("Has meeting link")
  }
}

/// Names the conferencing provider, for the ones worth naming.
///
/// Inherits the row's foreground rather than carrying the brand color: the name
/// already says which provider it is, so the color would only fight the event's.
struct ConferenceLabelView: View {
  let provider: ConferenceProvider

  var body: some View {
    Text(provider.rawValue)
      .font(.caption.weight(.bold))
      .help("Has \(provider.rawValue) link")
  }
}
