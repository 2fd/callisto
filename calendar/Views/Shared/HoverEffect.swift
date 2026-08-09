import SwiftUI

/// A view modifier that adds a hover effect with a rounded background.
struct EventHoverEffect: ViewModifier {
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  func body(content: Content) -> some View {
    content
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(
            isHovered && isEnabled ? Color.primary.opacity(0.06) : Color.clear
          )
      )
      .onHover { hovering in
        isHovered = hovering
      }
  }
}

extension View {
  /// Applies a hover effect with a subtle background highlight.
  func eventHoverEffect() -> some View {
    modifier(EventHoverEffect())
  }
}
