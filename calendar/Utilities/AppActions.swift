import AppKit
import SwiftUI

/// Windows defined by the app — the single source of truth for window IDs.
enum AppWindow: String {
    case settings
}

/// Opens an ``AppWindow`` via the SwiftUI scene graph, closing the current key
/// window and activating the app so the new window comes to the front.
struct OpenWindowsAction {
    fileprivate let handler: @MainActor (AppWindow) -> Void

    @MainActor
    func callAsFunction(_ window: AppWindow) {
        handler(window)
    }
}

extension EnvironmentValues {
    @Entry var openWindows: OpenWindowsAction = OpenWindowsAction { _ in }
}

/// Injects a real ``OpenWindowsAction`` that delegates to SwiftUI's
/// `@Environment(\.openWindow)`. Apply this modifier inside a `Scene`'s
/// content so the underlying `OpenWindowAction` is available.
struct OpenWindowsModifier: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.environment(\.openWindows, OpenWindowsAction { window in
            NSApp.keyWindow?.close()
            openWindow(id: window.rawValue)
            NSApp.activate(ignoringOtherApps: true)
        })
    }
}

extension View {
    /// Wires up `\.openWindows` so descendant views can call
    /// `openWindows(.settings)` without talking to `NSApp` directly.
    func openWindowsAction() -> some View {
        modifier(OpenWindowsModifier())
    }
}
