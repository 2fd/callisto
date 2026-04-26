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
            grantedScopes: [AuthConfig.calendarReadScope]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)
        #expect(decoded.accessToken == original.accessToken)
        #expect(decoded.refreshToken == original.refreshToken)
        #expect(decoded.expiresAt == original.expiresAt)
        #expect(decoded.grantedScopes == original.grantedScopes)
    }

    @Test func permissionHelpersReflectGrantedScopes() {
        let noCalendarScopes = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(3600),
            grantedScopes: []
        )
        #expect(!noCalendarScopes.canRead)
        #expect(!noCalendarScopes.canWrite)

        let readOnly = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(3600),
            grantedScopes: [AuthConfig.calendarReadScope]
        )
        #expect(readOnly.canRead)
        #expect(!readOnly.canWrite)

        let readWrite = OAuthTokens(
            accessToken: "a",
            refreshToken: "r",
            expiresAt: Date.now.addingTimeInterval(3600),
            grantedScopes: [AuthConfig.calendarReadScope, AuthConfig.eventsWriteScope]
        )
        #expect(readWrite.canRead)
        #expect(readWrite.canWrite)
    }
}
