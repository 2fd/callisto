import SwiftUI

extension Color {
    /// Creates a color from a hex string (e.g. `"#4285F4"` or `"4285F4"`).
    ///
    /// Falls back to Google blue (`#4285F4`) if the hex string is not a valid 6-character code.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0.26
            g = 0.52
            b = 0.96
        }

        self.init(red: r, green: g, blue: b)
    }
}
