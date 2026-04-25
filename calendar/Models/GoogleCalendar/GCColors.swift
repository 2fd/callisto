import Foundation

/// The Google Calendar colors resource.
///
/// This is a 1:1 `Codable` representation of the `calendar#colors` JSON
/// returned by the Google Calendar API v3. Contains palettes for both
/// calendar-level and event-level colors. All fields are guaranteed present
/// on read responses.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/colors#resource
nonisolated struct GCColors: Codable, Sendable {

    /// Type of the resource. Always `"calendar#colors"`.
    let kind: String
    /// Last modification time of the colors (RFC 3339 timestamp). Read-only.
    let updated: String
    /// A map of calendar color IDs to their definitions.
    /// Keys are color IDs (e.g. `"1"`, `"2"`, ..., `"24"`).
    let calendar: [String: GCColorDefinition]
    /// A map of event color IDs to their definitions.
    /// Keys are color IDs (e.g. `"1"`, `"2"`, ..., `"11"`).
    let event: [String: GCColorDefinition]
}

// MARK: - Color Definition

/// A single color definition with background and foreground colors.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/colors#resource
nonisolated struct GCColorDefinition: Codable, Sendable {
    /// The background color in hexadecimal format (e.g. `"#0088aa"`).
    let background: String
    /// The foreground color in hexadecimal format (e.g. `"#ffffff"`).
    /// May be used for text rendered on top of the background color.
    let foreground: String
}
