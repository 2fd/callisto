import SwiftUI

/// What an ``EventRow`` is painted on: one of the three treatments in
/// ``EventRowStyle/Treatment``.
struct EventRowBackground: View {
  let style: EventRowStyle
  let isHovering: Bool

  var body: some View {
    switch style.treatment {
    case .ongoing:
      OngoingEventBackground(
        tint: style.tint,
        sheen: style.onTint,
        isHovering: isHovering
      )
      .opacity(style.fillOpacity(isHovering: isHovering))

    case .bordered:
      RoundedRectangle(cornerRadius: 4)
        .fill(Self.rowSurface)
        .opacity(isHovering ? 0.85 : 1.0)
        .padding(.horizontal, 4)

      RoundedRectangle(cornerRadius: 4)
        .stroke(style.tint, lineWidth: 1)
        .opacity(0.5)
        .padding(.horizontal, 4)

    case .filled:
      RoundedRectangle(cornerRadius: 6)
        .fill(style.tint)
        .opacity(style.fillOpacity(isHovering: isHovering))
        .padding(.horizontal, 4)

      // Drawn over the fill rather than under it, so the pattern still reads
      // once the row is opaque.
      if style.isStriped {
        DiagonalStripesPattern(color: style.onTint)
          .cornerRadius(6)
          .padding(.horizontal, 4)
          .opacity(isHovering ? 0.28 : 0.18)
      }
    }
  }

  /// The window surface a bordered row shows through to.
  private static var rowSurface: Color {
    Color(nsColor: NSColor.alternatingContentBackgroundColors[1])
  }
}

/// A meeting happening now: the event's color, swept by a moving sheen.
private struct OngoingEventBackground: View {
  let tint: Color
  /// The band's color — the row's foreground, so the sweep reads as light on a
  /// dark event color and as shadow on a light one.
  let sheen: Color
  let isHovering: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(tint)
      .overlay {
        if reduceMotion {
          SkeletonShimmerBand(tint: sheen, progress: 0.5)
        } else {
          TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            SkeletonShimmerBand(
              tint: sheen,
              progress: Self.shimmerProgress(for: timeline.date)
            )
          }
        }
      }
      .opacity(isHovering ? 0.9 : 1.0)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .padding(.horizontal, 4)
  }

  /// Where the band sits in its cycle: one sweep across the row, then a pause
  /// parked off the trailing edge.
  private static func shimmerProgress(for date: Date) -> Double {
    let sweepDuration = 2.4
    let pauseDuration = 1.6
    let cycleDuration = sweepDuration + pauseDuration
    let cycleTime = date.timeIntervalSinceReferenceDate.truncatingRemainder(
      dividingBy: cycleDuration
    )

    guard cycleTime < sweepDuration else {
      return 1
    }

    return cycleTime / sweepDuration
  }
}

/// The travelling band itself: a soft gradient wider than half the row.
private struct SkeletonShimmerBand: View {
  let tint: Color
  let progress: Double

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let bandWidth = width * 0.58
      let travelDistance = width + bandWidth * 2
      let xOffset = CGFloat(progress) * travelDistance - bandWidth

      LinearGradient(
        stops: [
          .init(color: tint.opacity(0.0), location: 0.0),
          .init(color: tint.opacity(0.16), location: 0.34),
          .init(color: tint.opacity(0.32), location: 0.5),
          .init(color: tint.opacity(0.16), location: 0.66),
          .init(color: tint.opacity(0.0), location: 1.0),
        ],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(width: bandWidth)
      .offset(x: xOffset)
    }
  }
}
