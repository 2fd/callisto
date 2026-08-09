import SwiftUI

/// An event's hours, styled as one of the row's details.
///
/// Whether a row shows this at all, and where, is ``EventRowStyle``'s call —
/// this view only formats.
struct EventTimeRange: View {
  let event: GoogleCalendarEvent
  let style: EventRowStyle

  var body: some View {
    Text("\(start) - \(end)")
      .font(.caption)
      .strikethrough(style.isStruckThrough)
      .foregroundColor(style.detail)
  }

  private var start: String {
    event.startDate.formatted(date: .omitted, time: .shortened)
  }

  private var end: String {
    event.endDate.formatted(date: .omitted, time: .shortened)
  }
}
