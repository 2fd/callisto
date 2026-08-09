import Testing
import Foundation
@testable import calendar

@Suite("OAuthTokens")
struct OAuthTokensTests {
    @Test func isExpiredWhenPastExpiry() {
        let tokens = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(-10)
        )
        #expect(tokens.isExpired)
    }

    @Test func isExpiredWithin60SecondBuffer() {
        let tokens = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(30)
        )
        #expect(tokens.isExpired)
    }

    @Test func isNotExpiredWhenFarFuture() {
        let tokens = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(3600)
        )
        #expect(!tokens.isExpired)
    }

    @Test func codableRoundTrip() throws {
        let original = OAuthTokens(
            accessToken: "access123",
            refreshToken: "refresh456",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            grantedScopes: [AuthConfig.eventsReadScope]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)
        #expect(decoded.accessToken == original.accessToken)
        #expect(decoded.refreshToken == original.refreshToken)
        #expect(decoded.expiresAt == original.expiresAt)
        #expect(decoded.grantedScopes == original.grantedScopes)
    }

    private func tokens(_ scopes: [String]) -> OAuthTokens {
        OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(3600),
            grantedScopes: scopes
        )
    }

    @Test func permissionHelpersReflectGrantedScopes() {
        let none = tokens([])
        #expect(!none.canRead)
        #expect(!none.canWrite)

        let readOnly = tokens([AuthConfig.calendarListReadScope, AuthConfig.eventsReadScope])
        #expect(readOnly.canRead)
        #expect(!readOnly.canWrite)

        let readWrite = tokens([
            AuthConfig.calendarListReadScope,
            AuthConfig.eventsReadScope,
            AuthConfig.eventsWriteScope,
        ])
        #expect(readWrite.canRead)
        #expect(readWrite.canWrite)
    }

    /// Google returns only the scopes the user actually checked, so a consent
    /// where the write box was ticked and the read box was not must still read.
    @Test func writeScopeImpliesEventRead() {
        let writeOnly = tokens([AuthConfig.calendarListReadScope, AuthConfig.eventsWriteScope])
        #expect(writeOnly.canReadEvents)
        #expect(writeOnly.canRead)
        #expect(writeOnly.canWrite)
    }

    /// Half a grant syncs nothing: the calendar list names what to fetch and the
    /// event scope fetches it, so neither half alone counts as readable.
    @Test func partialCalendarGrantIsNotReadable() {
        let listOnly = tokens([AuthConfig.calendarListReadScope])
        #expect(listOnly.canListCalendars)
        #expect(!listOnly.canReadEvents)
        #expect(!listOnly.canRead)

        let eventsOnly = tokens([AuthConfig.eventsReadScope])
        #expect(!eventsOnly.canListCalendars)
        #expect(eventsOnly.canReadEvents)
        #expect(!eventsOnly.canRead)
    }

    /// Accounts linked before the app narrowed its scopes keep working.
    @Test func legacyBroadScopesStillGrantAccess() {
        let legacyReadOnly = tokens([AuthConfig.legacyCalendarReadScope])
        #expect(legacyReadOnly.canRead)
        #expect(!legacyReadOnly.canWrite)

        let legacyReadWrite = tokens([
            AuthConfig.legacyCalendarReadScope,
            AuthConfig.eventsWriteScope,
        ])
        #expect(legacyReadWrite.canRead)
        #expect(legacyReadWrite.canWrite)

        let legacyFull = tokens([AuthConfig.legacyCalendarFullScope])
        #expect(legacyFull.canRead)
        #expect(legacyFull.canWrite)
    }
}
