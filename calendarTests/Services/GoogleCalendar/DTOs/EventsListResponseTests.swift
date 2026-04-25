import Testing
import Foundation
@testable import calendar

@Suite("GCEventsListResponse decoding")
struct EventsListResponseTests {
    @Test func decodeFullEvent() throws {
        let json = """
        {
            "kind": "calendar#events",
            "etag": "\\"etag1\\"",
            "items": [{
                "kind": "calendar#event",
                "etag": "\\"evtEtag\\"",
                "id": "evt1",
                "iCalUID": "evt1@google.com",
                "sequence": 0,
                "eventType": "default",
                "summary": "Team Standup",
                "status": "confirmed",
                "htmlLink": "https://calendar.google.com/event?eid=evt1",
                "location": "Room 42",
                "description": "Daily standup",
                "start": {"dateTime": "2026-03-24T10:00:00Z"},
                "end": {"dateTime": "2026-03-24T10:30:00Z"},
                "conferenceData": {
                    "entryPoints": [{"entryPointType": "video", "uri": "https://meet.google.com/abc"}]
                },
                "hangoutLink": "https://meet.google.com/abc",
                "attendees": [
                    {"email": "user@example.com", "displayName": "User", "responseStatus": "accepted", "self": true}
                ]
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCEventsListResponse.self, from: json)
        #expect(response.kind == "calendar#events")
        let event = response.items.first
        #expect(event != nil)
        #expect(event?.id == "evt1")
        #expect(event?.summary == "Team Standup")
        #expect(event?.status == "confirmed")
        #expect(event?.location == "Room 42")
        #expect(event?.description == "Daily standup")
        #expect(event?.htmlLink != nil)
        #expect(event?.hangoutLink != nil)
        #expect(event?.start?.dateTime != nil)
        #expect(event?.end?.dateTime != nil)
    }

    @Test func decodeAllDayEvent() throws {
        let json = """
        {
            "kind": "calendar#events",
            "etag": "\\"etag1\\"",
            "items": [{
                "kind": "calendar#event",
                "etag": "\\"evtEtag\\"",
                "id": "evt3",
                "iCalUID": "evt3@google.com",
                "sequence": 0,
                "eventType": "default",
                "status": "confirmed",
                "start": {"date": "2026-03-24"},
                "end": {"date": "2026-03-25"}
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCEventsListResponse.self, from: json)
        let event = response.items.first
        #expect(event?.start?.date == "2026-03-24")
        #expect(event?.start?.dateTime == nil)
    }

    @Test func decodeEventWithConferenceData() throws {
        let json = """
        {
            "kind": "calendar#events",
            "etag": "\\"etag1\\"",
            "items": [{
                "kind": "calendar#event",
                "etag": "\\"evtEtag\\"",
                "id": "evt4",
                "iCalUID": "evt4@google.com",
                "sequence": 0,
                "eventType": "default",
                "status": "confirmed",
                "conferenceData": {"entryPoints": [{"entryPointType": "video", "uri": "https://zoom.us/j/123"}]}
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCEventsListResponse.self, from: json)
        let ep = response.items.first?.conferenceData?.entryPoints?.first
        #expect(ep?.entryPointType == "video")
        #expect(ep?.uri == "https://zoom.us/j/123")
    }

    @Test func decodeEventWithAttendees() throws {
        let json = """
        {
            "kind": "calendar#events",
            "etag": "\\"etag1\\"",
            "items": [{
                "kind": "calendar#event",
                "etag": "\\"evtEtag\\"",
                "id": "evt5",
                "iCalUID": "evt5@google.com",
                "sequence": 0,
                "eventType": "default",
                "status": "confirmed",
                "attendees": [{"email": "me@test.com", "self": true, "responseStatus": "accepted"}]
            }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GCEventsListResponse.self, from: json)
        let attendee = response.items.first?.attendees?.first
        #expect(attendee?.email == "me@test.com")
        #expect(attendee?.`self` == true)
        #expect(attendee?.responseStatus == "accepted")
    }

    @Test func decodeEmptyItems() throws {
        let json = """
        {"kind": "calendar#events", "etag": "\\"etag1\\"", "items": []}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(GCEventsListResponse.self, from: json)
        #expect(response.items.isEmpty)
    }
}
