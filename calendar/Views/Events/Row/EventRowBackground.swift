import SwiftUI

/// Quiet surfaces keep titles readable; the leading rail preserves calendar color.
struct EventRowBackground: View {
  let style: EventRowStyle
  let isHovering: Bool

  var body: some View {
    RoundedRectangle(cornerRadius: UI.EventCornerRadius)
      .fill(surface)
      .overlay {
        if style.treatment == .bordered {
          RoundedRectangle(cornerRadius: UI.EventCornerRadius)
            .strokeBorder(style.tint.opacity(0.35), lineWidth: 0.5)
        }
        if style.isStriped {
          DiagonalStripesPattern(color: style.tint.opacity(0.08))
            .clipShape(.rect(cornerRadius: UI.EventCornerRadius))
        }
      }
      .overlay(alignment: .leading) {
        if !style.isOutOfOffice {
          RoundedRectangle(cornerRadius: 1.5)
            .fill(style.tint)
            .frame(width: UI.EventIndicatorWidth)
            .padding(.vertical, 2)
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: UI.EventCornerRadius)
          .fill(.primary.opacity(isHovering ? 0.06 : 0))
      }
      .opacity(style.contentOpacity)
  }

  private var surface: Color {
    if style.isOutOfOffice { return Color.red.opacity(0.18) }
    if style.treatment == .ongoing { return style.tint.opacity(0.14) }
    return Color.primary.opacity(0.025)
  }
}
