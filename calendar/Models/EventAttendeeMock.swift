#if DEBUG
import Foundation

/// Factory for creating `EventAttendee` instances in tests and previews.
///
/// Every parameter has a sensible default so call sites only need to specify
/// the properties they care about. Call ``make(...)`` to get a fully
/// configured model instance ready for insertion into a `ModelContext`.
enum EventAttendeeMock {

    // MARK: - Factory

    /// Creates an `EventAttendee` populated with reasonable defaults.
    ///
    /// Override only the parameters relevant to your test case.
    static func make(
        email: String = "attendee@example.com",
        profileId: String? = nil,
        displayName: String? = nil,
        responseStatus: String = "accepted",
        isSelf: Bool = false,
        isOrganizer: Bool = false,
        isOptional: Bool = false,
        isResource: Bool = false,
        comment: String? = nil,
        additionalGuests: Int = 0
    ) -> EventAttendee {
        EventAttendee(
            email: email,
            profileId: profileId,
            displayName: displayName,
            responseStatus: responseStatus,
            isSelf: isSelf,
            isOrganizer: isOrganizer,
            isOptional: isOptional,
            isResource: isResource,
            comment: comment,
            additionalGuests: additionalGuests
        )
    }

    // MARK: - Presets

    /// The organizer of the event (current user).
    static func organizer(
        email: String = "me@gmail.com",
        displayName: String? = "Me"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "accepted",
            isSelf: true,
            isOrganizer: true
        )
    }

    /// An accepted guest.
    static func accepted(
        email: String = "accepted@example.com",
        displayName: String? = "Accepted Guest"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "accepted"
        )
    }

    /// A declined guest.
    static func declined(
        email: String = "declined@example.com",
        displayName: String? = "Declined Guest"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "declined"
        )
    }

    /// A tentative guest.
    static func tentative(
        email: String = "tentative@example.com",
        displayName: String? = "Tentative Guest"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "tentative"
        )
    }

    /// A guest who hasn't responded yet.
    static func needsAction(
        email: String = "pending@example.com",
        displayName: String? = "Pending Guest"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "needsAction"
        )
    }

    /// A conference room resource.
    static func room(
        email: String = "room@resource.calendar.google.com",
        displayName: String? = "Conference Room A"
    ) -> EventAttendee {
        make(
            email: email,
            displayName: displayName,
            responseStatus: "accepted",
            isResource: true
        )
    }
}
#endif
