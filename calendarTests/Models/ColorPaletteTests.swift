import Foundation
import Testing

@testable import calendar

@Suite("ColorPalette")
struct ColorPaletteTests {

    @Test("An event with no color of its own resolves to nothing")
    func noColorId() {
        #expect(ColorPalette.googleDefaults.event(nil) == nil)
        #expect(ColorPalette.googleDefaults.calendar(nil) == nil)
    }

    @Test("An ID outside the palette resolves to nothing rather than a wrong color")
    func unknownColorId() {
        #expect(ColorPalette.googleDefaults.event("99") == nil)
        #expect(ColorPalette.googleDefaults.calendar("99") == nil)
    }

    @Test("The built-in tables cover every ID Google currently serves")
    func defaultsCoverGooglesPalettes() {
        for id in 1...11 {
            #expect(
                ColorPalette.googleDefaults.event(String(id)) != nil,
                "event colorId \(id) missing from the built-in table"
            )
        }
        for id in 1...24 {
            #expect(
                ColorPalette.googleDefaults.calendar(String(id)) != nil,
                "calendar colorId \(id) missing from the built-in table"
            )
        }
    }

    @Test("The two palettes are separate namespaces")
    func palettesDoNotShareIDs() {
        // Event 7 is Peacock; calendar 7 is Eucalyptus.
        #expect(ColorPalette.googleDefaults.event("7") == "#039be5")
        #expect(ColorPalette.googleDefaults.calendar("7") == "#009688")
    }

    @Test("A known ID keeps the built-in color, not the one the endpoint serves")
    func builtInWinsOverFetchedValue() {
        // `/colors` still returns the legacy palettes — `#e1e1e1` for Graphite,
        // which renders as white, and `#9fe1e7` for a Peacock calendar.
        let palette = ColorPalette(
            GCColors.make(event: ["8": "#e1e1e1"], calendar: ["14": "#9fe1e7"])
        )

        #expect(palette.event("8") == "#616161")
        #expect(palette.calendar("14") == "#039be5")
    }

    @Test("A fetched palette contributes IDs the build does not know")
    func fetchedPaletteAddsUnknownIDs() {
        let palette = ColorPalette(
            GCColors.make(event: ["12": "#123456"], calendar: ["25": "#654321"])
        )

        #expect(palette.event("12") == "#123456")
        #expect(palette.calendar("25") == "#654321")
        // Merged, not replaced: the built-in IDs survive the fetch.
        #expect(palette.event("2") == "#33b679")
        #expect(palette.calendar("14") == "#039be5")
    }
}
