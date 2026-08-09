import AppKit
import SwiftUI

/// The translucent surface the menu bar panel draws its content on.
///
/// ``MenuBarPanel`` is borderless, so the material and the rounded corners are
/// ours to draw rather than the window's. Keeping them in a *view* — instead of
/// configuring the window — is what makes `#Preview` honest: a preview has no
/// window, so anything the window contributed would silently vanish from the
/// canvas and every vibrant foreground style would resolve against a flat fill
/// instead of against the material.
struct PopoverChrome<Content: View>: View {

  @ViewBuilder var content: Content

  var body: some View {
    content
      .background(
        VisualEffectBackground(
          material: .popover,
          // `.behindWindow` samples the desktop, which does not exist in the
          // preview canvas — it renders as a flat wash there. Previews sample
          // the backdrop ``MenuBarPreviewStage`` puts inside the window instead,
          // which is the closest the canvas gets to the real blend.
          blendingMode: Self.isPreview ? .withinWindow : .behindWindow
        )
      )
      .clipShape(.rect(cornerRadius: UI.PanelCornerRadius))
  }

  private static var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }
}

/// Hosts an `NSVisualEffectView` behind SwiftUI content.
private struct VisualEffectBackground: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    configure(view)
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    configure(view)
  }

  private func configure(_ view: NSVisualEffectView) {
    view.material = material
    view.blendingMode = blendingMode
    // The panel is dismissed the moment it stops being key, so it is never seen
    // in an inactive state. `.followsWindowActiveState` would only ever add a
    // desaturated frame on the way out.
    view.state = .active
  }
}

#if DEBUG
/// Places preview content on a stand-in desktop, so ``PopoverChrome``'s material
/// has something to blend with and the menu bar strip gives the panel a
/// believable anchor.
///
/// Without this, previews render the chrome over the canvas' flat background and
/// the vibrancy math produces colours the running app never shows.
struct MenuBarPreviewStage<Content: View>: View {

  var colorScheme: ColorScheme = .dark
  @ViewBuilder var content: Content

  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(
        colors: wallpaper,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Rectangle()
        .fill(.black.opacity(colorScheme == .dark ? 0.30 : 0.10))
        .frame(height: UI.MenuBarHeight)

      content
        .padding(.top, UI.MenuBarHeight + 6)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    .frame(width: UI.Width + 48)
    .preferredColorScheme(colorScheme)
  }

  private var wallpaper: [Color] {
    colorScheme == .dark
      ? [Color(red: 0.09, green: 0.12, blue: 0.28), Color(red: 0.42, green: 0.17, blue: 0.36)]
      : [Color(red: 0.60, green: 0.76, blue: 0.94), Color(red: 0.95, green: 0.86, blue: 0.74)]
  }
}
#endif
