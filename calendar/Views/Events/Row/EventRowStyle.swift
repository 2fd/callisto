import SwiftUI

/// Every visual decision an ``EventRow`` makes, resolved once from the entry and
/// the surface it is drawn on.
///
/// Kept free of `View` and of environment reads so the rules — which treatment a
/// row gets, which foreground survives on it — can be read, and tested, on their
/// own.
struct EventRowStyle {

  /// How the row is painted, and with it which foreground the text needs.
  ///
  /// The three are exclusive and cover every row: an event is either happening
  /// now, or something the user has waved off, or an ordinary event.
  enum Treatment {
    /// A meeting in progress: a subtle tint and a stronger title.
    case ongoing
    /// Declined, cancelled, or unanswered — outlined rather than filled, so it
    /// stays legible without claiming the space a real commitment does.
    case bordered
    /// The default: a quiet surface with a calendar-color indicator.
    case filled
  }

  let treatment: Treatment

  /// The event's color, toned for the surface it is painted on.
  let tint: Color

  /// Time off is the only ordinary row with a semantic color fill.
  let isOutOfOffice: Bool

  /// The row's primary text color.
  let title: Color

  /// Meetings in progress use a stronger title.
  let titleWeight: Font.Weight

  /// Times, icons, and anything else subordinate to the title.
  let detail: Color

  /// Declined and cancelled events are struck through.
  let isStruckThrough: Bool

  /// All-day and out-of-office rows say everything they have to say on one line.
  let isCompact: Bool

  /// A timed out-of-office row carries its time in the header, since it has no
  /// second line to put it on.
  let showsInlineTime: Bool

  /// Tentative rows get diagonal stripes over their fill.
  let isStriped: Bool

  /// Location and meeting link, which a past event no longer needs.
  let showsAccessories: Bool

  /// A past event is faded whole — content and fill together, or the text ends
  /// up washed out over full-strength color.
  let contentOpacity: Double

  init(entry: EventEntry, isDarkSurface: Bool, now: Date = .now) {
    let event = entry.event

    // Preserve the calendar color on the leading rail.
    let tintHex = Color.toned(entry.color, forDarkSurface: isDarkSurface)
    let tint = Color(hex: tintHex)

    let treatment = Self.resolveTreatment(for: event, now: now)

    self.treatment = treatment
    self.tint = tint
    self.isOutOfOffice = event.isOutOfOffice
    self.title = Color(nsColor: .labelColor)
    self.titleWeight = treatment == .ongoing ? .medium : .regular
    self.detail = Color(nsColor: .secondaryLabelColor)
    self.isStruckThrough = event.isDeclined || event.isCancelled
    self.isCompact = event.isAllDay || event.isOutOfOffice
    self.showsInlineTime = event.isOutOfOffice && !event.isAllDay
    self.isStriped = event.isTentative && treatment == .filled
    self.showsAccessories = !event.isPast
    self.contentOpacity = event.isPast ? 0.4 : 1.0
  }

  private static func resolveTreatment(
    for event: GoogleCalendarEvent,
    now: Date
  ) -> Treatment {
    if isOngoing(event, now: now) { return .ongoing }
    if event.isDeclined || event.isCancelled || event.needsAction {
      return .bordered
    }
    return .filled
  }

  /// A meeting the user is in right now — which is only ever a timed event they
  /// have not turned down.
  private static func isOngoing(_ event: GoogleCalendarEvent, now: Date) -> Bool {
    let isMeeting = !event.isAllDay && !event.isBirthday && !event.isOutOfOffice
    let isOnTheHook =
      event.isAccepted || event.isConfirmed || event.isTentative
    let isUnderway = event.startDate < now && event.endDate > now
    return isMeeting && isOnTheHook && isUnderway
  }
}
