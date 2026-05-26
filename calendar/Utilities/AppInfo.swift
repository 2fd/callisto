import Foundation

/// Bundle-backed application metadata for user-facing labels.
enum AppInfo {
  static var displayName: String {
    displayName(infoDictionary: Bundle.main.infoDictionary)
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
