import AppKit
import SwiftUI

/// Installs a right-click context menu on the app's menu bar status item.
///
/// `MenuBarExtra(.window)` does not expose its underlying `NSStatusItem` and
/// does not surface right-clicks, so we intercept `.rightMouseDown` with a
/// local `NSEvent` monitor, present an `NSMenu`, and swallow the event so the
/// popover does not also open.
@MainActor
final class MenuBarRightClick {

  private var monitor: Any?
  private weak var eventManager: GoogleCalendarEventManager?
  private weak var accountManager: GoogleAccountManager?
  private var openSettings: (() -> Void)?

  func start(
    eventManager: GoogleCalendarEventManager,
    accountManager: GoogleAccountManager,
    openSettings: @escaping () -> Void
  ) {
    guard monitor == nil else { return }
    self.eventManager = eventManager
    self.accountManager = accountManager
    self.openSettings = openSettings

    monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) {
      [weak self] event in
      MainActor.assumeIsolated {
        self?.handle(event) ?? event
      }
    }
  }

  private func handle(_ event: NSEvent) -> NSEvent? {
    guard isStatusBarEvent(event) else { return event }
    buildMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    return nil
  }

  // Local monitors only see this process's events; `MenuBarExtra`'s popover
  // window is not a status-bar window, so a class-name check is enough to
  // keep popover right-clicks from triggering the context menu.
  private func isStatusBarEvent(_ event: NSEvent) -> Bool {
    event.window?.className.contains("StatusBar") == true
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false

    if let accountManager {
      if !accountManager.isEmpty {}
      for account in accountManager.iter() {
        let email = account.email
        let authuser = account.authuser
        menu.addItem(
          ClosureMenuItem(title: "Open \(email)") {
            guard
              let url = URL(
                string: "https://calendar.google.com/calendar/u/\(authuser)/r"
              )
            else { return }
            NSWorkspace.shared.open(url)
          }
        )
      }
      menu.addItem(.separator())
    }

    menu.addItem(
      ClosureMenuItem(title: "Add Account…") { [weak self] in
        guard
          let accountManager = self?.accountManager,
          let eventManager = self?.eventManager
        else { return }
        Task { @MainActor in
          guard await accountManager.upsert() != nil else { return }
          await eventManager.sync()
        }
      }
    )

    menu.addItem(.separator())

    menu.addItem(
      ClosureMenuItem(title: "Open Settings…") { [weak self] in
        self?.openSettings?()
      }
    )

    menu.addItem(
      ClosureMenuItem(title: "Quit CalendarBar", keyEquivalent: "q") {
        NSApp.terminate(nil)
      }
    )

    return menu
  }
}

/// `NSMenuItem` subclass that invokes a closure when selected — Cocoa's
/// `target/action` does not natively accept closures.
private final class ClosureMenuItem: NSMenuItem {

  private let block: () -> Void

  init(title: String, keyEquivalent: String = "", _ block: @escaping () -> Void)
  {
    self.block = block
    super.init(
      title: title,
      action: #selector(invoke),
      keyEquivalent: keyEquivalent
    )
    self.target = self
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc private func invoke() { block() }
}
