import Testing
import Foundation
@testable import calendar

@Suite("URL.zoomAppURL")
struct ZoomAppURLTests {
    @Test func convertsJoinLinkKeepingHostAndPassword() {
        let url = URL(string: "https://us06web.zoom.us/j/81455711555?pwd=hx2rvHaxBmHtlquJTqZobM6Iw3Y0yi.1&jst=2&authuser=0#success")!
        #expect(
            url.zoomAppURL?.absoluteString
                == "zoomus://us06web.zoom.us/join?action=join&confno=81455711555&pwd=hx2rvHaxBmHtlquJTqZobM6Iw3Y0yi.1"
        )
    }

    @Test func convertsJoinLinkWithoutPassword() {
        let url = URL(string: "https://zoom.us/j/123456789?authuser=1")!
        #expect(url.zoomAppURL?.absoluteString == "zoomus://zoom.us/join?action=join&confno=123456789")
    }

    @Test func keepsVanitySubdomain() {
        let url = URL(string: "https://acme.zoom.us/j/123456789?pwd=abc")!
        #expect(url.zoomAppURL?.host == "acme.zoom.us")
    }

    @Test func rejectsPersonalLink() {
        let url = URL(string: "https://zoom.us/my/someone")!
        #expect(url.zoomAppURL == nil)
    }

    @Test func rejectsNonNumericMeetingId() {
        let url = URL(string: "https://zoom.us/j/abc123")!
        #expect(url.zoomAppURL == nil)
    }

    @Test func rejectsLookalikeHost() {
        let url = URL(string: "https://evilzoom.us/j/123456789")!
        #expect(url.zoomAppURL == nil)
    }

    @Test func rejectsOtherProviders() {
        let url = URL(string: "https://meet.google.com/abc-defg-hij?authuser=0")!
        #expect(url.zoomAppURL == nil)
    }
}
