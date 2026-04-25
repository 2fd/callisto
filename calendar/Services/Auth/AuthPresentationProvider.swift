import AppKit
import AuthenticationServices

/// Provides the presentation anchor for `ASWebAuthenticationSession`.
///
/// Returns the frontmost visible window (typically the settings window) so the
/// authentication sheet attaches to a real window.
final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first ?? {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                             styleMask: .borderless, backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            return w
        }()
    }
}
