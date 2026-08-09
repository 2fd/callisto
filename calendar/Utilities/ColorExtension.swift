import SwiftUI

extension Color {
    /// Creates a color from a hex string (e.g. `"#4285F4"` or `"4285F4"`).
    ///
    /// Falls back to Google blue (`#4285F4`) if the hex string is not a valid 6-character code.
    init(hex: String) {
        let (r, g, b) = Color.components(hex: hex)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// The palette color as it should be painted on a dark surface.
    ///
    /// Google authors both palettes for a light background and tones them down
    /// itself in dark mode — Peacock ships as `#039be5` and is drawn closer to
    /// `#619bd3`. Painted full strength on a near-black list the same color
    /// glares, so the saturation is pulled back and the brightness capped.
    /// Returns hex so the result can be handed to ``readable(on:)``, which has
    /// to judge contrast against what is actually on screen.
    static func toned(_ hex: String, forDarkSurface dark: Bool) -> String {
        guard dark else { return hex }

        let (r, g, b) = components(hex: hex)
        guard
            let source = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
                .usingColorSpace(.sRGB)
        else { return hex }

        var h: CGFloat = 0
        var s: CGFloat = 0
        var v: CGFloat = 0
        var a: CGFloat = 0
        source.getHue(&h, saturation: &s, brightness: &v, alpha: &a)

        let toned = NSColor(
            colorSpace: .sRGB,
            hue: h,
            saturation: s * darkSurfaceSaturation,
            brightness: min(v * darkSurfaceBrightness, darkSurfaceBrightnessCeiling),
            alpha: 1
        )
        return String(
            format: "#%02X%02X%02X",
            Int((toned.redComponent * 255).rounded()),
            Int((toned.greenComponent * 255).rounded()),
            Int((toned.blueComponent * 255).rounded())
        )
    }

    private static let darkSurfaceSaturation: CGFloat = 0.55
    private static let darkSurfaceBrightness: CGFloat = 0.95
    private static let darkSurfaceBrightnessCeiling: CGFloat = 0.85

    /// Black or white — whichever stays legible drawn on `hex`.
    ///
    /// A fixed choice cannot serve the whole event palette: it runs from
    /// `#f6bf26` (Banana) to `#3f51b5` (Blueberry), and white text disappears
    /// on the first while black disappears on the second. The pivot is WCAG's
    /// relative luminance, the quantity its contrast ratio is defined on.
    static func readable(on hex: String) -> Color {
        let (r, g, b) = components(hex: hex)
        let luminance =
            0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        return luminance > darkTextLuminance
            ? Color(.sRGB, red: 0.11, green: 0.11, blue: 0.11, opacity: 1)
            : Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
    }

    /// Where the text flips from white to near-black.
    ///
    /// Pure contrast maximization pivots at 0.179, where white and black are
    /// equally legible. Google puts white on everything up to a far lighter
    /// color — white on a toned Tomato, dark only once the fill reaches
    /// something like a toned Peacock or Banana — and matching it matters more
    /// here than the extra contrast, since these rows are short strings on
    /// large fills. This threshold reproduces its choices across both palettes.
    private static let darkTextLuminance = 0.35

    /// Undoes the sRGB transfer function, as WCAG's luminance is defined on
    /// light-linear values rather than on the encoded channel.
    private static func linear(_ channel: Double) -> Double {
        channel <= 0.03928
            ? channel / 12.92
            : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func components(hex: String) -> (Double, Double, Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        switch hex.count {
        case 6:
            return (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            return (0.26, 0.52, 0.96)
        }
    }
}
