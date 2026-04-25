import Testing
import SwiftUI
import AppKit
@testable import calendar

@Suite("Color+hex")
struct ColorExtensionTests {
    @Test func validHexWithHash() {
        let color = Color(hex: "#FF0000")
        let ns = NSColor(color).usingColorSpace(.deviceRGB)!
        #expect(ns.redComponent > 0.99)
        #expect(ns.greenComponent < 0.01)
        #expect(ns.blueComponent < 0.01)
    }

    @Test func validHexWithoutHash() {
        let color = Color(hex: "00FF00")
        let ns = NSColor(color).usingColorSpace(.deviceRGB)!
        #expect(ns.redComponent < 0.01)
        #expect(ns.greenComponent > 0.99)
        #expect(ns.blueComponent < 0.01)
    }

    @Test func invalidHexFallsBack() {
        let color = Color(hex: "XYZ")
        let fallback = Color(hex: "#4285F4")
        let ns1 = NSColor(color).usingColorSpace(.deviceRGB)!
        let ns2 = NSColor(fallback).usingColorSpace(.deviceRGB)!
        #expect(abs(ns1.redComponent - ns2.redComponent) < 0.02)
        #expect(abs(ns1.greenComponent - ns2.greenComponent) < 0.02)
        #expect(abs(ns1.blueComponent - ns2.blueComponent) < 0.02)
    }

    @Test func emptyStringFallsBack() {
        let color = Color(hex: "")
        let fallback = Color(hex: "#4285F4")
        let ns1 = NSColor(color).usingColorSpace(.deviceRGB)!
        let ns2 = NSColor(fallback).usingColorSpace(.deviceRGB)!
        #expect(abs(ns1.redComponent - ns2.redComponent) < 0.02)
        #expect(abs(ns1.greenComponent - ns2.greenComponent) < 0.02)
        #expect(abs(ns1.blueComponent - ns2.blueComponent) < 0.02)
    }
}
