import AppKit
import SwiftUI

/// Windows defined by the app — the single source of truth for window IDs.
enum AppWindow: String {
    case settings
}

/// Opens an ``AppWindow``.
///
/// Injected by ``AppDelegate``, which owns the windows. Views call
/// `openWindows(.settings)` and stay unaware of AppKit.
struct OpenWindowsAction {
    fileprivate let handler: @MainActor (AppWindow) -> Void

    @MainActor
    func callAsFunction(_ window: AppWindow) {
        handler(window)
    }

    init(_ handler: @escaping @MainActor (AppWindow) -> Void) {
        self.handler = handler
    }
}

extension EnvironmentValues {
    @Entry var openWindows: OpenWindowsAction = OpenWindowsAction { _ in }
}

extension Notification.Name {
    /// Posted when something finishes an action that should close the menu bar
    /// panel — following an event link, opening settings, pressing Escape.
    static let dismissMenuBarPanel = Notification.Name(
        "\(Constants.subsystem).dismissMenuBarPanel"
    )
}

/// Closes the menu bar panel if it is open.
///
/// The panel is an ``MenuBarPanel``, not the key window, so callers must not
/// reach for `NSApp.keyWindow` — that would close the settings window whenever
/// the panel was not focused.
func dismissMenuBarPanel() {
    NotificationCenter.default.post(name: .dismissMenuBarPanel, object: nil)
}
