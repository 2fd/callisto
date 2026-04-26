import Testing
import Foundation
import SwiftData
@testable import calendar

@Suite("GoogleAccount model")
@MainActor
struct AccountTests {
    @Test func createAndFetchAccount() throws {
        let container = try TestModelContainer.create()
        let context = container.mainContext

        let account = GoogleAccount(accountId: "abc", email: "a@b.com", displayName: "Test User")
        context.insert(account)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GoogleAccount>())
        #expect(fetched.count == 1)
        #expect(fetched[0].accountId == "abc")
        #expect(fetched[0].email == "a@b.com")
        #expect(fetched[0].displayName == "Test User")
    }

    @Test func defaultValues() {
        let account = GoogleAccount(accountId: "x", email: "x@y.com", displayName: "X")
        #expect(account.isVisible == true)
        #expect(account.lastSyncedAt == nil)
        #expect(account.canRead == true)
        #expect(account.canWrite == false)
    }
}
