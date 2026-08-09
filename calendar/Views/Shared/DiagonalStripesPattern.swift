import SwiftUI

/// Draws parallel diagonal lines at 45 degrees.
struct DiagonalStripesPattern: View {
  var spacing: CGFloat = 12
  var lineWidth: CGFloat = 6
  var color: Color = .primary

  var body: some View {
    Canvas { context, size in
      let h = size.height
      let w = size.width
      var x: CGFloat = -h

      while x < w + h {
        var path = Path()
        path.move(to: CGPoint(x: x + h, y: -h))
        path.addLine(to: CGPoint(x: x - h * 2, y: h * 2))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
        x += spacing + lineWidth
      }
    }
  }
}
