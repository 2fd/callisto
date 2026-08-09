import SwiftUI

/// A small trailing icon on an ``EventRow``, standing in for something the title
/// does not say: that the event is time off, a birthday, flagged important, or
/// abandoned by everyone else invited.
struct EventBadge: Identifiable {

  /// How much the badge is allowed to shout.
  enum Emphasis {
    /// Subordinate to the title, like the rest of the row's details.
    case detail
    /// Its own color, because the row's is not the point.
    case warning
  }

  let symbol: String
  let help: String
  var emphasis: Emphasis = .detail

  var id: String { symbol }

  /// The badges an event earns, in the order they are laid out.
  ///
  /// Out of office and birthday are all-day-only: a timed out-of-office row
  /// shows its hours in that slot instead.
  static func all(for event: GoogleCalendarEvent) -> [EventBadge] {
    var badges: [EventBadge] = []

    if event.isAllDay {
      if event.isOutOfOffice {
        badges.append(EventBadge(symbol: "minus.circle.fill", help: "out of office"))
      } else if event.isBirthday {
        badges.append(EventBadge(symbol: "gift", help: "birthday"))
      }
    }

    if event.isImportant {
      badges.append(
        EventBadge(
          symbol: "exclamationmark.triangle.fill",
          help: "important",
          emphasis: .warning
        )
      )
    }

    if event.allOtherAttendeesDeclined {
      badges.append(
        EventBadge(symbol: "person.2.slash.fill", help: "all attendees declined")
      )
    }

    return badges
  }
}

/// The row's badges, drawn at one size in one place.
struct EventBadgeStrip: View {
  let event: GoogleCalendarEvent
  let style: EventRowStyle

  var body: some View {
    ForEach(EventBadge.all(for: event)) { badge in
      Image(systemName: badge.symbol)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 12, height: 12)
        .foregroundStyle(color(for: badge))
        .help(badge.help)
    }
  }

  private func color(for badge: EventBadge) -> Color {
    switch badge.emphasis {
    case .detail: style.detail
    case .warning: .yellow
    }
  }
}
