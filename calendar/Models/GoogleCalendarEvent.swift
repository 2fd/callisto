import Foundation
import SwiftData

/// A single calendar event persisted locally via SwiftData.
///
/// Synced from the Google Calendar API. Uniquely identified by a composite key
/// of `calendarId/eventId` to avoid collisions across calendars.
@Model
final class GoogleCalendarEvent {

  // MARK: - Identity

  @Attribute(.unique) var compositeId: String
  var eventId: String
  /// ID of the owning ``GoogleAccount``.
  var accountId: String
  /// ID of the owning ``GoogleCalendar``.
  var calendarId: String
  var etag: String
  var iCalUID: String
  var sequence: Int

  // MARK: - Content

  var summary: String
  var eventDescription: String?
  var location: String?
  var colorId: String?

  // MARK: - Time

  var startDate: Date
  var endDate: Date
  var isAllDay: Bool
  var startTimeZone: String?
  var endTimeZone: String?
  var endTimeUnspecified: Bool = false

  // MARK: - Status & Visibility

  var status: String
  var transparency: String = "opaque"
  var visibility: String = "default"
  var htmlLink: String

  var isImportant: Bool = false

  // MARK: - Event Type

  var eventType: String = EventType.default

  // MARK: - People (flattened)

  var creatorEmail: String?
  var creatorDisplayName: String?
  var creatorIsSelf: Bool = false
  var organizerEmail: String?
  var organizerDisplayName: String?
  var organizerIsSelf: Bool = false

  // MARK: - Recurrence

  var recurringEventId: String?

  // MARK: - Conferencing (flattened)

  var conferenceLink: String?

  /// The provider behind ``conferenceLink``, when it is one the app names.
  /// `nil` covers every other video link, which is tagged generically.
  var conferenceProvider: ConferenceProvider? {
    guard let conferenceLink else { return nil }
    if conferenceLink.contains("zoom.us") { return .zoom }
    if conferenceLink.contains("meet.google.com") { return .meet }
    return nil
  }

  var conferenceColor: String {
    conferenceProvider?.brandColor ?? "34A853"
  }


  var conferenceSolutionName: String?
  var conferenceSolutionIconUri: String?
  var conferenceId: String?
  var hangoutLink: String?
  var conferenceNotes: String?

  // MARK: - Guest Permissions

  var guestsCanInviteOthers: Bool = true
  var guestsCanModify: Bool = false
  var guestsCanSeeOtherGuests: Bool = true
  var privateCopy: Bool = false
  var locked: Bool = false
  var attendeesOmitted: Bool = false

  // MARK: - Reminders

  var remindersUseDefault: Bool = true

  // MARK: - Source

  var sourceUrl: String?
  var sourceTitle: String?

  // MARK: - Timestamps

  var createdAt: Date?
  var updatedAt: Date?
  /// App-local timestamp of the last successful fetch from the API, or `nil` if never synced.
  var lastSyncedAt: Date?

  // MARK: - JSON Blobs

  @Attribute(.allowsCloudEncryption) var conferenceEntryPointsJSON: Data?
  @Attribute(.allowsCloudEncryption) var recurrenceJSON: Data?
  @Attribute(.allowsCloudEncryption) var originalStartTimeJSON: Data?
  @Attribute(.allowsCloudEncryption) var extendedPropertiesJSON: Data?
  @Attribute(.allowsCloudEncryption) var outOfOfficePropertiesJSON: Data?
  @Attribute(.allowsCloudEncryption) var focusTimePropertiesJSON: Data?
  @Attribute(.allowsCloudEncryption) var workingLocationPropertiesJSON: Data?
  @Attribute(.allowsCloudEncryption) var birthdayPropertiesJSON: Data?

  // MARK: - Conference Link Extraction

  static func extractConferenceLink(from event: GCEvent) -> String? {
    event.conferenceData?.entryPoints?
      .first(where: { $0.entryPointType == "video" })?.uri
      ?? event.hangoutLink
      ?? extractZoomLink(from: event.description)
  }

  private static func extractZoomLink(from description: String?) -> String? {
    guard let description else { return nil }
    let pattern = #"https?://[\w.-]*zoom\.us/j/[^\s<"\)]+"#
    guard
      let range = description.range(of: pattern, options: .regularExpression)
    else { return nil }
    return String(description[range])
  }

  // MARK: - Computed

  var isPast: Bool { endDate < Date.now }
  var isOutOfOffice: Bool { eventType == EventType.outOfOffice }
  var isFocusTime: Bool { eventType == EventType.focusTime }
  var isWorkingLocation: Bool { eventType == EventType.workingLocation }
  var isBirthday: Bool { eventType == EventType.birthday }
  var showsAsBusy: Bool { transparency == "opaque" }
  var isPrivate: Bool {
    visibility == "private" || visibility == "confidential"
  }
  var isRecurring: Bool { recurringEventId != nil }

  var isAccepted: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.accepted
      : status == EventStatus.accepted
  }
  var isConfirmed: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.confirmed
      : status == EventStatus.confirmed
  }
  var isCancelled: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.cancelled
      : status == EventStatus.cancelled
  }
  var isDeclined: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.declined
      : status == EventStatus.declined
  }
  var needsAction: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.needsAction
      : status == EventStatus.needsAction
  }
  var isTentative: Bool {
    selfResponseStatus != nil
      ? selfResponseStatus == EventStatus.tentative
      : status == EventStatus.tentative
  }

  var totalAttendees: Int { attendees.count }
  var acceptedCount: Int {
    attendees.filter { $0.responseStatus == EventStatus.accepted }.count
  }
  var selfAttendee: EventAttendee? { attendees.first { $0.isSelf } }
  var selfResponseStatus: String? { selfAttendee?.responseStatus }
  var isTentativelyAccepted: Bool {
    selfResponseStatus == EventStatus.tentative
  }

  var allOtherAttendeesDeclined: Bool {
    let others = attendees.filter { !$0.isSelf }
    guard !others.isEmpty else { return false }
    return others.allSatisfy { $0.responseStatus == EventStatus.declined }
  }

  // MARK: - Relationships

  @Relationship(deleteRule: .cascade, inverse: \EventAttendee.event)
  var attendees: [EventAttendee]

  @Relationship(deleteRule: .cascade, inverse: \EventAttachment.event)
  var attachments: [EventAttachment]

  @Relationship(deleteRule: .cascade, inverse: \EventReminder.event)
  var reminders: [EventReminder]

  // MARK: - Init

  init(
    compositeId: String,
    eventId: String,
    accountId: String,
    calendarId: String,
    etag: String,
    iCalUID: String,
    sequence: Int,
    summary: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool,
    htmlLink: String,
    status: String,
    eventType: String = "default"
  ) {
    self.compositeId = compositeId
    self.eventId = eventId
    self.accountId = accountId
    self.calendarId = calendarId
    self.etag = etag
    self.iCalUID = iCalUID
    self.sequence = sequence
    self.summary = summary
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.htmlLink = htmlLink
    self.status = status
    self.eventType = eventType
    self.attendees = []
    self.attachments = []
    self.reminders = []
  }

  /// Creates a new event from a Google Calendar API event.
  convenience init?(from event: GCEvent, accountId: String, calendarId: String)
  {
    guard let start = event.start.flatMap(Self.parseEventDateTime),
      let end = event.end.flatMap(Self.parseEventDateTime)
    else {
      return nil
    }

    let raw = event.summary ?? "No Title"
    let important = raw.hasPrefix("[IMPORTANT]")
    let s =
      important
      ? String(raw.dropFirst("[IMPORTANT]".count)).trimmingCharacters(
        in: .whitespaces
      ) : raw

    self.init(
      compositeId: "\(calendarId)/\(event.id)",
      eventId: event.id,
      accountId: accountId,
      calendarId: calendarId,
      etag: event.etag,
      iCalUID: event.iCalUID,
      sequence: event.sequence,
      summary: s,
      startDate: start.date,
      endDate: end.date,
      isAllDay: start.isAllDay || Self.isMidnightToMidnight(
        event.start,
        event.end
      ),
      htmlLink: event.htmlLink ?? "",
      status: event.status,
      eventType: event.eventType
    )
    isImportant = important
    startTimeZone = event.start?.timeZone
    endTimeZone = event.end?.timeZone
    applyFields(from: event)
    lastSyncedAt = .now
  }

  /// Updates mutable fields from a Google Calendar API event, preserving identity.
  ///
  /// Attendees, attachments, and reminders are the manager's responsibility.
  func update(from event: GCEvent) {
    guard let start = event.start.flatMap(Self.parseEventDateTime),
      let end = event.end.flatMap(Self.parseEventDateTime)
    else {
      return
    }

    let raw = event.summary ?? "No Title"
    let important = raw.hasPrefix("[IMPORTANT]")

    etag = event.etag
    iCalUID = event.iCalUID
    sequence = event.sequence
    summary =
      important
      ? String(raw.dropFirst("[IMPORTANT]".count)).trimmingCharacters(
        in: .whitespaces
      ) : raw
    isImportant = important
    startDate = start.date
    endDate = end.date
    isAllDay =
      start.isAllDay || Self.isMidnightToMidnight(event.start, event.end)
    htmlLink = event.htmlLink ?? ""
    status = event.status
    eventType = event.eventType
    startTimeZone = event.start?.timeZone
    endTimeZone = event.end?.timeZone
    applyFields(from: event)
    lastSyncedAt = .now
  }

  private func applyFields(from e: GCEvent) {
    eventDescription = e.description
    location = e.location
    colorId = e.colorId

    endTimeUnspecified = e.endTimeUnspecified ?? false

    transparency = e.transparency ?? "opaque"
    visibility = e.visibility ?? "default"

    creatorEmail = e.creator?.email
    creatorDisplayName = e.creator?.displayName
    creatorIsSelf = e.creator?.`self` ?? false
    organizerEmail = e.organizer?.email
    organizerDisplayName = e.organizer?.displayName
    organizerIsSelf = e.organizer?.`self` ?? false

    recurringEventId = e.recurringEventId

    conferenceLink = Self.extractConferenceLink(from: e)
    conferenceSolutionName = e.conferenceData?.conferenceSolution?.name
    conferenceSolutionIconUri = e.conferenceData?.conferenceSolution?.iconUri
    conferenceId = e.conferenceData?.conferenceId
    hangoutLink = e.hangoutLink
    conferenceNotes = e.conferenceData?.notes

    guestsCanInviteOthers = e.guestsCanInviteOthers ?? true
    guestsCanModify = e.guestsCanModify ?? false
    guestsCanSeeOtherGuests = e.guestsCanSeeOtherGuests ?? true
    privateCopy = e.privateCopy ?? false
    locked = e.locked ?? false
    attendeesOmitted = e.attendeesOmitted ?? false

    remindersUseDefault = e.reminders?.useDefault ?? true

    sourceUrl = e.source?.url
    sourceTitle = e.source?.title

    createdAt = e.created.flatMap(Date.init(rfc3339:))
    updatedAt = e.updated.flatMap(Date.init(rfc3339:))

    let encoder = JSONEncoder()
    conferenceEntryPointsJSON = e.conferenceData?.entryPoints.flatMap {
      try? encoder.encode($0)
    }
    recurrenceJSON = e.recurrence.flatMap { try? encoder.encode($0) }
    originalStartTimeJSON = e.originalStartTime.flatMap {
      try? encoder.encode($0)
    }
    extendedPropertiesJSON = e.extendedProperties.flatMap {
      try? encoder.encode($0)
    }
    outOfOfficePropertiesJSON = e.outOfOfficeProperties.flatMap {
      try? encoder.encode($0)
    }
    focusTimePropertiesJSON = e.focusTimeProperties.flatMap {
      try? encoder.encode($0)
    }
    workingLocationPropertiesJSON = e.workingLocationProperties.flatMap {
      try? encoder.encode($0)
    }
    birthdayPropertiesJSON = e.birthdayProperties.flatMap {
      try? encoder.encode($0)
    }
  }
}

private let dateOnlyFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "yyyy-MM-dd"
  f.timeZone = TimeZone.current
  return f
}()

extension GoogleCalendarEvent {
  /// Parses a `GCEventDateTime` into a date + all-day flag.
  static func parseEventDateTime(_ dto: GCEventDateTime) -> (
    date: Date, isAllDay: Bool
  )? {
    if let s = dto.dateTime, let d = Date(rfc3339: s) {
      return (d, false)
    }
    if let s = dto.date, let d = dateOnlyFormatter.date(from: s) {
      return (d, true)
    }
    return nil
  }

  static func isMidnightToMidnight(
    _ start: GCEventDateTime?,
    _ end: GCEventDateTime?
  ) -> Bool {
    guard let startDateTime = start?.dateTime,
      let endDateTime = end?.dateTime
    else {
      return false
    }

    return isMidnightDateTime(startDateTime) && isMidnightDateTime(endDateTime)
  }

  private static func isMidnightDateTime(_ value: String) -> Bool {
    guard let timeStart = value.firstIndex(of: "T") else {
      return false
    }

    let time = value[value.index(after: timeStart)...]
    return time.hasPrefix("00:00:00")
  }
}

/// A conferencing provider the app labels by name rather than by icon.
enum ConferenceProvider: String, Sendable {
  case zoom
  case meet

  /// Brand color the label is drawn in.
  var brandColor: String {
    switch self {
    case .zoom: "2D8CFF"
    case .meet: "fed812"
    }
  }
}

/// An event bundled with the calendar and account it belongs to, so views
/// never have to resolve those associations themselves.
struct EventEntry: Identifiable {
  let event: GoogleCalendarEvent
  let calendar: GoogleCalendar
  let account: GoogleAccount
  /// Hex color the row is drawn in: the event's own when it has one, otherwise
  /// its calendar's. Resolved once at construction, where the account's palette
  /// is in reach, so views never have to.
  let color: String

  var id: String { event.compositeId }
}

/// A single day's events, returned by ``GoogleCalendarEventManager/iterByDays(_:)``.
struct EventDay: Identifiable {
  let day: Date
  private let entries: [EventEntry]

  var id: Date { day }

  init(day: Date, entries: [EventEntry]) {
    self.day = day
    self.entries = entries
  }

  func iter() -> [EventEntry] { entries }
}
