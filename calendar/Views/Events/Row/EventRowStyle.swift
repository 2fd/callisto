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
  /// now, or something the user has waved off, or an ordinary block of color.
  enum Treatment {
    /// A meeting in progress: the event's color, swept by a moving sheen.
    case ongoing
    /// Declined, cancelled, or unanswered — outlined rather than filled, so it
    /// stays legible without claiming the space a real commitment does.
    case bordered
    /// The default: a solid block of the event's color.
    case filled
  }

  let treatment: Treatment

  /// The event's color, toned for the surface it is painted on.
  let tint: Color

  /// Text that sits directly on ``tint``.
  let onTint: Color

  /// The row's primary text color.
  let title: Color

  /// A bordered row states its title more quietly: it is not a commitment.
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

    // Toned first, then judged: `onTint` has to contrast with what is actually
    // on screen, not with the palette value.
    let tintHex = Color.toned(entry.color, forDarkSurface: isDarkSurface)
    let tint = Color(hex: tintHex)
    let onTint = Color.readable(on: tintHex)

    let treatment = Self.resolveTreatment(for: event, now: now)
    let isBordered = treatment == .bordered

    self.treatment = treatment
    self.tint = tint
    self.onTint = onTint
    // A bordered row is not painted in the event's color, so its text lands on
    // the window surface and takes the tint itself. Every other row is, and so
    // needs the color that survives on top of it — out of office included, which
    // carries its own `colorId` (Tomato) and needs no hard-coded red.
    self.title = isBordered ? tint : onTint
    self.titleWeight = isBordered ? .light : .medium
    self.detail = isBordered ? tint : onTint.opacity(0.85)
    self.isStruckThrough = event.isDeclined || event.isCancelled
    self.isCompact = event.isAllDay || event.isOutOfOffice
    self.showsInlineTime = event.isOutOfOffice && !event.isAllDay
    self.isStriped = event.isTentative && treatment == .filled
    self.showsAccessories = !event.isPast
    self.contentOpacity = event.isPast ? 0.4 : 1.0
  }

  /// The fill's opacity: dimmed under the pointer, and faded again with the
  /// content when the event is past.
  func fillOpacity(isHovering: Bool) -> Double {
    (isHovering ? 0.85 : 1.0) * contentOpacity
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
