import Foundation
import Testing

@testable import calendar

@Suite("GCColors decoding")
struct GCColorsTests {

    @Test func decodeColors() throws {
        let json = """
            {
                "kind": "calendar#colors",
                "updated": "2012-02-14T00:00:00.000Z",
                "calendar": {
                    "1": { "background": "#ac725e", "foreground": "#1d1d1d" }
                },
                "event": {
                    "1": { "background": "#a4bdfc", "foreground": "#1d1d1d" },
                    "11": { "background": "#dc2127", "foreground": "#1d1d1d" }
                }
            }
            """.data(using: .utf8)!

        let colors = try JSONDecoder().decode(GCColors.self, from: json)

        #expect(colors.kind == "calendar#colors")
        #expect(colors.updated == "2012-02-14T00:00:00.000Z")
        #expect(colors.calendar["1"]?.background == "#ac725e")
        #expect(colors.event["11"]?.background == "#dc2127")
        #expect(colors.event["11"]?.foreground == "#1d1d1d")
        // The two palettes are separate namespaces: the same ID means a
        // different color in each.
        #expect(colors.event["1"]?.background != colors.calendar["1"]?.background)
    }
}
