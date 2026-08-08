import AppKit
import SwiftUI

/// Hosts ``SettingsWindow`` in a real `NSWindow`.
///
/// The app drives its UI from AppKit (see ``AppDelegate``), and the menu bar
/// panel lives outside SwiftUI's scene graph, so `@Environment(\.openWindow)` is
/// not available to it — there is no public way to open a SwiftUI `Window(id:)`
/// scene from AppKit. Owning the window here is what lets the panel and the
/// status item's context menu both open settings.
@MainActor
final class SettingsWindowController: NSWindowController {

  init(rootView: some View) {
    let hosting = NSHostingController(rootView: AnyView(rootView))

    let window = NSWindow(contentViewController: hosting)
    window.title = "\(AppInfo.displayName) Settings"
    // No `.resizable`: the SwiftUI content fixes its own width and minimum
    // height, matching the `windowResizability(.contentSize)` this replaces.
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.isReleasedWhenClosed = false
    window.center()

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// Brings the window forward, centring it the first time it is shown.
  func show() {
    if window?.isVisible != true {
      window?.center()
    }
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}
