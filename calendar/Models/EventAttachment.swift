import Foundation
import SwiftData

/// A file attachment on a calendar event, persisted via SwiftData.
///
/// Attachments are synced from the Google Calendar API. Max 25 per event.
@Model
final class EventAttachment {
    /// URL link to the attachment.
    var fileUrl: String
    /// Attachment title.
    var title: String?
    /// Internet media type (MIME type) of the attachment.
    var mimeType: String?
    /// URL link to the attachment's icon.
    var iconLink: String?
    /// ID of the attached file. For Google Drive files, this is the Drive file ID.
    var fileId: String?

    /// The event this attachment belongs to.
    var event: GoogleCalendarEvent?

    init(
        fileUrl: String,
        title: String? = nil,
        mimeType: String? = nil,
        iconLink: String? = nil,
        fileId: String? = nil
    ) {
        self.fileUrl = fileUrl
        self.title = title
        self.mimeType = mimeType
        self.iconLink = iconLink
        self.fileId = fileId
    }

    /// Creates a new attachment from a Google Calendar API attachment.
    /// Returns `nil` if the attachment has no file URL.
    convenience init?(from attachment: GCAttachment) {
        guard let fileUrl = attachment.fileUrl else { return nil }
        self.init(
            fileUrl: fileUrl,
            title: attachment.title,
            mimeType: attachment.mimeType,
            iconLink: attachment.iconLink,
            fileId: attachment.fileId
        )
    }
}
