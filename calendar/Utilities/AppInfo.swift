import Foundation

/// Bundle-backed application metadata for user-facing labels.
///
/// `nonisolated` because the networking layer reads it while building the
/// User-Agent, off the main actor. Reading the Info dictionary is thread-safe.
nonisolated enum AppInfo {
  static var displayName: String {
    displayName(infoDictionary: Bundle.main.infoDictionary)
  }

  /// Short marketing version (`CFBundleShortVersionString`), for the User-Agent.
  static var version: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      ?? "0.0.0"
  }

  static func displayName(infoDictionary: [String: Any]?) -> String {
    let keys = ["CFBundleDisplayName", "CFBundleName", "CFBundleExecutable"]

    for key in keys {
      guard
        let value = infoDictionary?[key] as? String,
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { continue }

      return value
    }

    return "Callisto"
  }
}
