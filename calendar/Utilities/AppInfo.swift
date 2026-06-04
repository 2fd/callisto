import Foundation

/// Bundle-backed application metadata for user-facing labels.
enum AppInfo {
  static var isNightlyBuild: Bool {
    #if NIGHTLY
      return isNightlyBuild(nightlyCompilationCondition: true)
    #else
      return isNightlyBuild(nightlyCompilationCondition: false)
    #endif
  }

  static var displayName: String {
    displayName(infoDictionary: Bundle.main.infoDictionary)
  }

  static var version: String {
    version(infoDictionary: Bundle.main.infoDictionary)
  }

  static var buildID: String {
    buildID(infoDictionary: Bundle.main.infoDictionary)
  }

  static func isNightlyBuild(nightlyCompilationCondition: Bool) -> Bool {
    nightlyCompilationCondition
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

  static func version(infoDictionary: [String: Any]?) -> String {
    stringValue(
      for: "CFBundleShortVersionString",
      in: infoDictionary,
      fallback: "Unknown"
    )
  }

  static func buildID(infoDictionary: [String: Any]?) -> String {
    stringValue(
      for: "CFBundleVersion",
      in: infoDictionary,
      fallback: "Unknown"
    )
  }

  private static func stringValue(
    for key: String,
    in infoDictionary: [String: Any]?,
    fallback: String
  ) -> String {
    guard
      let value = infoDictionary?[key] as? String,
      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return fallback }

    return value
  }
}
