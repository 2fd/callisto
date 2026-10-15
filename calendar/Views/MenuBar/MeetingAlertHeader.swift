import SwiftUI

/// A section header in ``MeetingAlertView``: what the rows below are, and when.
///
/// Matches ``DaySectionHeader``'s type so the alert reads as part of the same
/// surface as the popover.
struct MeetingAlertHeader<Detail: View>: View {

  enum Tone {
    case accent
    case warning

    var color: Color {
      switch self {
      case .accent: .accentColor
      case .warning: .orange
      }
    }
  }

  let tone: Tone
  let title: LocalizedStringKey
  /// Draws the title in the tone, for a header that is itself the news.
  var tintsTitle = false
  @ViewBuilder var detail: Detail

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.system(size: 11))
        .fontWeight(.semibold)
        .textCase(.uppercase)
        .foregroundStyle(tintsTitle ? AnyShapeStyle(tone.color) : AnyShapeStyle(.secondary))

      Spacer()

      detail
        .font(.system(size: 11))
        .foregroundStyle(tone.color)
    }
    .padding(.horizontal, 4)
    .padding(.top, 4)
    .padding(.bottom, 2)
  }
}

extension MeetingAlertHeader where Detail == Text? {
  /// A header whose title carries the tone and whose detail is plain secondary
  /// text, or none.
  init(title: LocalizedStringKey, detail: String?, tone: Tone) {
    self.tone = tone
    self.title = title
    self.tintsTitle = true
    self.detail = detail.map { Text($0).foregroundStyle(.secondary) }
  }
}

/// "starts in 4:32" / "ends in 5 min", kept live while the panel is up.
struct CountdownText: View {

  enum Style {
    /// Seconds matter: the user is deciding when to leave the current event.
    case starts
    /// Minutes are enough for the event being wrapped up.
    case ends
  }

  let date: Date
  let style: Style

  init(to date: Date, style: Style) {
    self.date = date
    self.style = style
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      Text(label(at: context.date))
        .monospacedDigit()
    }
  }

  private func label(at now: Date) -> String {
    let remaining = max(0, date.timeIntervalSince(now))
    switch style {
    case .starts:
      let clock = Duration.seconds(Int(remaining)).formatted(.time(pattern: .minuteSecond))
      return String(localized: "starts in \(clock)")
    case .ends:
      let minutes = Int((remaining / 60).rounded(.up))
      return minutes > 0
        ? String(localized: "ends in \(minutes) min")
        : String(localized: "ending now")
    }
  }
}
