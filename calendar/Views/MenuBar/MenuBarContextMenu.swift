import AppKit

/// Builds the status item's right-click menu.
///
/// Previously this had to be presented from a global `.rightMouseDown` monitor
/// because `MenuBarExtra` hid its `NSStatusItem`. ``MenuBarController`` now owns
/// the item, so the menu is attached to it the way AppKit expects.
@MainActor
func makeMenuBarContextMenu(
  eventManager: GoogleCalendarEventManager,
  accountManager: GoogleAccountManager,
  openSettings: @escaping () -> Void
) -> NSMenu {
  let menu = NSMenu()
  menu.autoenablesItems = false

  if !accountManager.isEmpty {
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
    ClosureMenuItem(title: "Add Account…") {
      Task { @MainActor in
        guard let account = await accountManager.upsert(), account.canRead
        else { return }
        await eventManager.sync()
      }
    }
  )

  menu.addItem(.separator())

  menu.addItem(ClosureMenuItem(title: "Open Settings…") { openSettings() })

  menu.addItem(
    ClosureMenuItem(title: "Quit \(AppInfo.displayName)", keyEquivalent: "q") {
      NSApp.terminate(nil)
    }
  )

  return menu
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
