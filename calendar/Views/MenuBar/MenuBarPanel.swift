import AppKit
import SwiftUI

/// Borderless panel that hangs the popover under the status item.
///
/// Replaces the window `MenuBarExtra(.window)` used to provide. Owning it lets
/// ``PopoverChrome`` draw the material and corners — see that type for why the
/// chrome lives in a view — and lets the panel keep its *top* edge pinned while
/// SwiftUI content grows.
final class MenuBarPanel: NSPanel {

  /// Screen point the panel's top edge is pinned to.
  ///
  /// `NSWindow` keeps its bottom-left origin fixed when it resizes, so content
  /// growing by a day's worth of events would drag the top edge down and away
  /// from the menu bar. Every frame change is re-anchored against this instead.
  private var topLeft: NSPoint?

  init(rootView: AnyView) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: UI.Width, height: 1),
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    contentViewController = NSHostingController(rootView: rootView)

    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    isMovable = false
    isFloatingPanel = true
    hidesOnDeactivate = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    animationBehavior = .utilityWindow
  }

  /// The panel takes key focus so scrolling, hover and buttons behave; it never
  /// becomes main, which would put it in the window cycle.
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  /// Pins the panel below `buttonFrame`, clamped to the screen it sits on.
  func anchor(below buttonFrame: NSRect, on screen: NSScreen?) {
    var x = buttonFrame.midX - frame.width / 2

    if let visible = (screen ?? NSScreen.main)?.visibleFrame {
      let margin = UI.PanelGap
      x = min(max(x, visible.minX + margin), visible.maxX - frame.width - margin)
    }

    topLeft = NSPoint(x: x, y: buttonFrame.minY - UI.PanelGap)
    setFrame(frame, display: false)
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    var rect = frameRect
    if let topLeft {
      rect.origin = NSPoint(x: topLeft.x, y: topLeft.y - rect.height)
    }
    super.setFrame(rect, display: flag)
  }

  /// Escape closes the panel, matching every other menu bar surface.
  override func cancelOperation(_ sender: Any?) {
    dismissMenuBarPanel()
  }
}
