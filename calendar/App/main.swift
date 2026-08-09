import AppKit

// Explicit entry point rather than `@main` on ``AppDelegate``.
//
// `@main` on an `NSApplicationDelegate` compiles and starts a run loop, but
// AppKit never installs the delegate here — `applicationDidFinishLaunching`
// is not called and the status item is never created. Assigning the delegate
// before `run()` is unambiguous.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
