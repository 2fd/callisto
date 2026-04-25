#if DEBUG
    import Foundation

    /// Factory for creating ``GoogleAccount`` instances in tests and previews.
    enum GoogleAccountMock {

        static func make(
            accountId: String = "mock-account",
            email: String = "user@gmail.com",
            displayName: String = "Mock User",
            isVisible: Bool = true,
            hasEventsWriteScope: Bool = false,
            authuser: Int = 0
        ) -> GoogleAccount {
            GoogleAccount(
                accountId: accountId,
                email: email,
                displayName: displayName,
                isVisible: isVisible,
                hasEventsWriteScope: hasEventsWriteScope,
                authuser: authuser
            )
        }

        static func primary(authuser: Int = 0) -> GoogleAccount {
            make(authuser: authuser)
        }
    }
#endif
