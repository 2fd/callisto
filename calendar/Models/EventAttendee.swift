import Foundation
import SwiftData

/// A single attendee on a calendar event, persisted via SwiftData.
///
/// Attendees are synced from the Google Calendar API as part of each event.
/// Persists all fields from the `attendees[]` array in the event resource.
@Model
final class EventAttendee {
    /// The attendee's email address.
    var email: String
    /// The attendee's Profile ID, if available.
    var profileId: String?
    /// Human-readable display name, if available.
    var displayName: String?
    /// The attendee's response status (e.g. `"needsAction"`, `"accepted"`, `"declined"`, `"tentative"`).
    var responseStatus: String
    /// Whether this attendee represents the current authenticated user.
    var isSelf: Bool
    /// Whether this attendee is the event organizer.
    var isOrganizer: Bool
    /// Whether this attendee is marked as optional.
    var isOptional: Bool
    /// Whether this attendee is a resource (e.g. a conference room).
    var isResource: Bool
    /// The attendee's RSVP comment.
    var comment: String?
    /// Number of additional guests this attendee is bringing.
    var additionalGuests: Int

    /// The event this attendee belongs to.
    var event: GoogleCalendarEvent?

    init(
        email: String,
        profileId: String? = nil,
        displayName: String? = nil,
        responseStatus: String,
        isSelf: Bool = false,
        isOrganizer: Bool = false,
        isOptional: Bool = false,
        isResource: Bool = false,
        comment: String? = nil,
        additionalGuests: Int = 0
    ) {
        self.email = email
        self.profileId = profileId
        self.displayName = displayName
        self.responseStatus = responseStatus
        self.isSelf = isSelf
        self.isOrganizer = isOrganizer
        self.isOptional = isOptional
        self.isResource = isResource
        self.comment = comment
        self.additionalGuests = additionalGuests
    }

    /// Creates a new attendee from a Google Calendar API attendee.
    /// Returns `nil` if the attendee has no email address.
    convenience init?(from attendee: GCAttendee) {
        guard let email = attendee.email else { return nil }
        self.init(
            email: email,
            profileId: attendee.id,
            displayName: attendee.displayName,
            responseStatus: attendee.responseStatus ?? EventStatus.needsAction,
            isSelf: attendee.`self` ?? false,
            isOrganizer: attendee.organizer ?? false,
            isOptional: attendee.`optional` ?? false,
            isResource: attendee.resource ?? false,
            comment: attendee.comment,
            additionalGuests: attendee.additionalGuests ?? 0
        )
    }
}
