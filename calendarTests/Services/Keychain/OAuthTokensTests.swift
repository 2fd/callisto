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
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)
        #expect(decoded.accessToken == original.accessToken)
        #expect(decoded.refreshToken == original.refreshToken)
        #expect(decoded.expiresAt == original.expiresAt)
    }
}
