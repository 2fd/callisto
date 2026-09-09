import SwiftUI

/// Quiet surfaces keep titles readable; the leading rail preserves calendar color.
struct EventRowBackground: View {
  let style: EventRowStyle
  let isHovering: Bool

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: UI.EventCornerRadius, style: .circular)
  }

  var body: some View {
    shape
      .fill(surface)
      .overlay {
        if style.isStriped {
          DiagonalStripesPattern(color: style.tint.opacity(0.08))
        }
      }
      .overlay(alignment: .leading) {
        if !style.isOutOfOffice {
          RoundedRectangle(cornerRadius: UI.EventIndicatorCornerRadius, style: .circular)
            .fill(style.tint)
            .frame(width: UI.EventIndicatorWidth)
            .padding(.vertical, UI.EventIndicatorInset)
            .padding(.leading, UI.EventIndicatorInset)
        }
      }
      .overlay {
        Color.primary.opacity(isHovering ? 0.06 : 0)
      }
      .clipShape(shape)
      .overlay {
        if style.treatment == .bordered {
          shape.strokeBorder(style.tint.opacity(0.35), lineWidth: 0.5)
        }
      }
      .opacity(style.contentOpacity)
  }

  private var surface: Color {
    if style.isOutOfOffice { return Color.red.opacity(0.18) }
    if style.treatment == .ongoing { return style.tint.opacity(0.14) }
    return Color.primary.opacity(0.025)
  }
}
