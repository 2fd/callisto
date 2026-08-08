import AppKit
import SwiftUI

/// Owns the status item and the panel it opens.
///
/// Replaces `MenuBarExtra`, which had two limits this app cares about:
///
/// - it renders its label into a *template* image, so ``ConferenceIconView``'s
///   per-provider colour collapsed to the flat menu bar tint;
/// - it does not expose its `NSStatusItem`, so right-clicks had to be stolen
///   with a global `NSEvent` monitor and matched by window class name.
///
/// Hosting the label in an `NSHostingView` keeps its colour, and the status item
/// button reports both mouse buttons directly.
@MainActor
final class MenuBarController: NSObject, NSWindowDelegate {

  private let statusItem = NSStatusBar.system.statusItem(
    withLength: NSStatusItem.variableLength
  )
  private let panel: MenuBarPanel
  private let buildContextMenu: () -> NSMenu

  /// When the panel was last hidden, used to swallow the re-open described in
  /// ``togglePanel()``.
  private var dismissedAt: Date = .distantPast
  private var dismissObserver: (any NSObjectProtocol)?

  init(
    label: some View,
    content: some View,
    contextMenu: @escaping () -> NSMenu
  ) {
    buildContextMenu = contextMenu
    panel = MenuBarPanel(rootView: AnyView(content))
    super.init()

    panel.delegate = self
    installLabel(AnyView(label))

    dismissObserver = NotificationCenter.default.addObserver(
      forName: .dismissMenuBarPanel,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.hide() }
    }
  }

  deinit {
    if let dismissObserver {
      NotificationCenter.default.removeObserver(dismissObserver)
    }
  }

  // MARK: - Status item

  private func installLabel(_ label: AnyView) {
    guard let button = statusItem.button else { return }

    button.target = self
    button.action = #selector(handleClick)
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])

    let host = StatusItemHostingView(rootView: label)
    host.sizingOptions = [.intrinsicContentSize]
    host.translatesAutoresizingMaskIntoConstraints = false
    host.onWidthChange = { [weak self] width in
      self?.statusItem.length = min(width, UI.MenuBarMaxWidth)
    }

    button.addSubview(host)
    NSLayoutConstraint.activate([
      host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
      host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
    ])

    statusItem.length = min(host.intrinsicContentSize.width, UI.MenuBarMaxWidth)
  }

  @objc private func handleClick() {
    let event = NSApp.currentEvent
    let isSecondary =
      event?.type == .rightMouseUp
      || event?.modifierFlags.contains(.control) == true

    if isSecondary {
      showContextMenu()
    } else {
      togglePanel()
    }
  }

  private func showContextMenu() {
    hide()

    // Assigning `menu` and clicking is the only way to get AppKit to present a
    // menu with the status item's own highlight and placement; it is cleared
    // straight after so left-clicks keep reaching `handleClick`.
    statusItem.menu = buildContextMenu()
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  // MARK: - Panel

  private func togglePanel() {
    if panel.isVisible {
      hide()
      return
    }

    // The mouse-*down* that preceded this click already made the panel resign
    // key, which hid it. Without the guard the mouse-up would reopen it and a
    // click on the status item would never close the panel.
    guard Date.now.timeIntervalSince(dismissedAt) > 0.2 else { return }
    show()
  }

  private func show() {
    guard
      let button = statusItem.button,
      let buttonWindow = button.window
    else { return }

    let buttonFrame = buttonWindow.convertToScreen(
      button.convert(button.bounds, to: nil)
    )
    panel.anchor(below: buttonFrame, on: buttonWindow.screen)

    // An accessory app has no windows to activate through, so the panel only
    // gets real key focus if the app is activated with it.
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  private func hide() {
    guard panel.isVisible else { return }
    dismissedAt = .now
    panel.orderOut(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    hide()
  }
}

/// `NSHostingView` sized for a status item button.
///
/// Reports its SwiftUI ideal width so the status item can size itself, and
/// declines every hit test so clicks reach the button underneath rather than
/// being swallowed by the hosted content.
private final class StatusItemHostingView<Content: View>: NSHostingView<Content> {

  var onWidthChange: ((CGFloat) -> Void)?

  private var lastReportedWidth: CGFloat = -1

  required init(rootView: Content) {
    super.init(rootView: rootView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func layout() {
    super.layout()

    let width = intrinsicContentSize.width
    guard width.isFinite, width > 0, width != lastReportedWidth else { return }
    lastReportedWidth = width
    onWidthChange?(width)
  }
}
