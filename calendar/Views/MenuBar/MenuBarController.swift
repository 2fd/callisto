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
  /// Hangs a ``MeetingAlertView`` under the status item without taking focus.
  /// Its own panel, so the popover's never changes shape or behaviour for it.
  private let alertPanel: MenuBarPanel
  private let buildContextMenu: () -> NSMenu

  /// When the panel was last hidden, used to swallow the re-open described in
  /// ``togglePanel()``.
  private var dismissedAt: Date = .distantPast
  private var dismissObserver: (any NSObjectProtocol)?
  private var alertDismissObserver: (any NSObjectProtocol)?
  private var statusWindowObservers: [any NSObjectProtocol] = []

  /// An alert that arrived while the popover was open, shown once it closes so
  /// the two panels never stack on the same spot.
  private var hasPendingAlert = false

  /// `compositeId`s of the events the alert announces. Acting on one of them —
  /// from the alert, the popover or a notification — uses the alert. The event
  /// in progress a heads-up shows under "Now" is context, not one of them:
  /// rejoining it must not throw away the warning about the next one.
  var alertEventIds: Set<String> = []

  /// Called when the user puts away the alert — acting on one of its events,
  /// Dismiss, Escape, or a click on the status item.
  var onAlertDismissed: (() -> Void)?

  init(
    label: some View,
    content: some View,
    alert: some View,
    contextMenu: @escaping () -> NSMenu
  ) {
    buildContextMenu = contextMenu
    panel = MenuBarPanel(rootView: AnyView(content))
    alertPanel = MenuBarPanel(rootView: AnyView(alert))
    super.init()

    panel.delegate = self
    installLabel(AnyView(label))

    dismissObserver = NotificationCenter.default.addObserver(
      forName: .dismissMenuBarPanel,
      object: nil,
      queue: .main
    ) { [weak self] note in
      let eventId = note.userInfo?[dismissedEventIdKey] as? String
      MainActor.assumeIsolated { self?.dismissAll(actingOn: eventId) }
    }

    alertDismissObserver = NotificationCenter.default.addObserver(
      forName: .dismissMeetingAlert,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.dismissAlert() }
    }
    // Escape on the alert dismisses the alert, not whatever the popover is doing.
    alertPanel.onCancel = dismissMeetingAlert
  }

  deinit {
    for observer in [dismissObserver, alertDismissObserver].compactMap({ $0 }) + statusWindowObservers {
      NotificationCenter.default.removeObserver(observer)
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

    // The label changes with the next event — often on the very tick an alert
    // appears — and the status bar moves the item's window on its own layout
    // pass. Re-anchor the alert whenever that window moves or resizes.
    if let itemWindow = button.window {
      statusWindowObservers = [NSWindow.didMoveNotification, NSWindow.didResizeNotification]
        .map { name in
          NotificationCenter.default.addObserver(
            forName: name,
            object: itemWindow,
            queue: .main
          ) { [weak self] _ in
            MainActor.assumeIsolated {
              guard let self, self.alertPanel.isVisible else { return }
              _ = self.anchor(self.alertPanel)
            }
          }
        }
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
    // A click on the status item puts the alert away and opens the popover in
    // its place: the user went looking for their events. Unless the alert was
    // waiting behind the popover and this very click revealed it, by closing
    // the popover on mouse-down (see the guard below).
    let revealedByThisClick = Date.now.timeIntervalSince(dismissedAt) <= 0.2
    if alertPanel.isVisible, !revealedByThisClick {
      dismissAlert()
    }

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
    guard anchor(panel) else { return }

    // An accessory app has no windows to activate through, so the panel only
    // gets real key focus if the app is activated with it.
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  private func hide() {
    guard panel.isVisible else { return }
    dismissedAt = .now
    panel.orderOut(nil)

    if hasPendingAlert {
      hasPendingAlert = false
      showAlert()
    }
  }

  /// Pins `panel` under the status item button; `false` when the button has no
  /// window to anchor to yet.
  private func anchor(_ panel: MenuBarPanel) -> Bool {
    guard
      let button = statusItem.button,
      let buttonWindow = button.window
    else { return false }

    let buttonFrame = buttonWindow.convertToScreen(
      button.convert(button.bounds, to: nil)
    )
    panel.anchor(below: buttonFrame, on: buttonWindow.screen)
    return true
  }

  /// Handles `.dismissMenuBarPanel`, posted when something finishes an action.
  ///
  /// The popover always closes. The alert closes, and counts as used, only when
  /// the action was on one of its events — joining or opening it, from the
  /// alert, the popover or a notification. Anything else (Settings, another
  /// event, More events) leaves the alert alone, and one waiting behind the
  /// popover appears once it closes.
  private func dismissAll(actingOn eventId: String?) {
    let usedAlert =
      (alertPanel.isVisible || hasPendingAlert)
      && eventId.map(alertEventIds.contains) == true
    if usedAlert {
      hasPendingAlert = false
    }
    hide()
    if usedAlert {
      dismissAlert()
    }
  }

  /// The user put the alert away: Dismiss, Escape, or acting on its event.
  private func dismissAlert() {
    hideAlert()
    onAlertDismissed?()
  }

  // MARK: - Alert

  /// Shows the alert panel without activating the app, so whatever the user is
  /// typing into keeps focus. Waits for the popover to close if it is open.
  ///
  /// The alert has no implicit close: no click-outside, no timeout. It goes
  /// when the user acts on it, or when ``hideAlert()`` is called because it no
  /// longer applies.
  func presentAlert() {
    if panel.isVisible {
      hasPendingAlert = true
      return
    }
    showAlert()
  }

  /// Hides the alert panel without reporting it as dismissed by the user.
  func hideAlert() {
    hasPendingAlert = false
    guard alertPanel.isVisible else { return }
    alertPanel.orderOut(nil)
  }

  private func showAlert() {
    // The content was set a moment ago; lay it out first so the panel is
    // anchored at its real size, not the empty one.
    alertPanel.contentView?.layoutSubtreeIfNeeded()
    guard anchor(alertPanel) else { return }
    alertPanel.orderFrontRegardless()
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
