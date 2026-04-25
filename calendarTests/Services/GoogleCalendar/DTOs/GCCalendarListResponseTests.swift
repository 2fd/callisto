import Testing
import Foundation
@testable import calendar

@Suite("GCCalendarListResponse decoding")
struct GCCalendarListResponseTests {
    @Test func decodeCalendarList() throws {
        let json = """
        {
            "kind": "calendar#calendarList",
            "etag": "\\"list-etag\\"",
            "items": [
                {
                    "kind": "calendar#calendarListEntry",
                    "etag": "\\"entry1-etag\\"",
                    "id": "cal1",
                    "summary": "Work",
                    "backgroundColor": "#4285F4",
                    "selected": true,
                    "accessRole": "owner"
                },
                {
                    "kind": "calendar#calendarListEntry",
                    "etag": "\\"entry2-etag\\"",
                    "id": "cal2",
                    "summary": "Personal",
                    "backgroundColor": "#0B8043",
                    "selected": false,
                    "accessRole": "reader"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCCalendarListResponse.self, from: json)
        #expect(response.kind == "calendar#calendarList")
        #expect(response.items.count == 2)
        #expect(response.items[0].id == "cal1")
        #expect(response.items[0].summary == "Work")
        #expect(response.items[0].backgroundColor == "#4285F4")
        #expect(response.items[0].selected == true)
        #expect(response.items[0].accessRole == "owner")
        #expect(response.items[1].accessRole == "reader")
    }

    @Test func decodeMinimalEntry() throws {
        let json = """
        {
            "kind": "calendar#calendarList",
            "etag": "\\"list-etag\\"",
            "items": [
                {
                    "kind": "calendar#calendarListEntry",
                    "etag": "\\"entry-etag\\"",
                    "id": "cal3",
                    "accessRole": "reader"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCCalendarListResponse.self, from: json)
        let entry = response.items[0]
        #expect(entry.id == "cal3")
        #expect(entry.accessRole == "reader")
        #expect(entry.summary == nil)
        #expect(entry.backgroundColor == nil)
        #expect(entry.selected == nil)
    }
}
