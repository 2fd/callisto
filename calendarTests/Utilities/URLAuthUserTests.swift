import Testing
import Foundation
@testable import calendar

@Suite("URL.settingAuthUser")
struct URLAuthUserTests {
    @Test func appendsWhenMissing() {
        let url = URL(string: "https://calendar.google.com/event?eid=evt1")!
        let result = url.settingAuthUser(2)
        let items = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first(where: { $0.name == "authuser" })?.value == "2")
        #expect(items.first(where: { $0.name == "eid" })?.value == "evt1")
    }

    @Test func overwritesExistingAuthUser() {
        let url = URL(string: "https://calendar.google.com/event?eid=evt1&authuser=0")!
        let result = url.settingAuthUser(3)
        let items = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let authuserItems = items.filter { $0.name == "authuser" }
        #expect(authuserItems.count == 1)
        #expect(authuserItems.first?.value == "3")
        #expect(items.first(where: { $0.name == "eid" })?.value == "evt1")
    }

    @Test func preservesOtherParams() {
        let url = URL(string: "https://meet.google.com/abc?hs=122&ijlm=xyz")!
        let result = url.settingAuthUser(1)
        let items = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first(where: { $0.name == "hs" })?.value == "122")
        #expect(items.first(where: { $0.name == "ijlm" })?.value == "xyz")
        #expect(items.first(where: { $0.name == "authuser" })?.value == "1")
    }

    @Test func appendsToURLWithoutQuery() {
        let url = URL(string: "https://meet.google.com/abc-defg-hij")!
        let result = url.settingAuthUser(1)
        #expect(result.absoluteString == "https://meet.google.com/abc-defg-hij?authuser=1")
    }
}
