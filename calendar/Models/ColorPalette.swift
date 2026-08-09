import Foundation

/// One account's color palettes, indexed by the IDs Google reports on events
/// and on calendar list entries.
///
/// Both halves of the `colors` resource still serve the pastel values Google
/// stopped drawing years ago: Peacock arrives as `#9fe1e7` where the product
/// renders `#039be5`, and Graphite as `#e1e1e1`, which reads as white. The same
/// legacy values reach the app a second way — `calendarList` resolves a
/// calendar's color into `backgroundColor` from that same stale table — so
/// there is no source of current values to fetch. They are built in here.
///
/// The fetch still pays for itself: it is the only way an ID added after this
/// build ships can reach the app at all.
///
/// The palettes are per account, not global: `/colors` is an authenticated
/// endpoint and nothing in its contract promises two accounts the same answer.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/colors
nonisolated struct ColorPalette: Sendable, Equatable {

    private let eventBackgrounds: [String: String]
    private let calendarBackgrounds: [String: String]

    init(event: [String: String], calendar: [String: String]) {
        self.eventBackgrounds = event
        self.calendarBackgrounds = calendar
    }

    /// Builds a palette from a fetched `colors` resource, keeping the built-in
    /// value for every ID the app already knows.
    init(_ colors: GCColors) {
        self.init(
            event: Self.currentEvent.merging(colors.event.mapValues(\.background)) {
                builtIn, _ in builtIn
            },
            calendar: Self.currentCalendar.merging(colors.calendar.mapValues(\.background)) {
                builtIn, _ in builtIn
            }
        )
    }

    /// The background hex for an event's own color, or `nil` when the event has
    /// none — the common case, where it inherits its calendar's color.
    func event(_ colorId: String?) -> String? {
        guard let colorId else { return nil }
        return eventBackgrounds[colorId]
    }

    /// The background hex for a calendar's palette color.
    ///
    /// `nil` when the calendar has no `colorId`, which is how a calendar with a
    /// custom RGB color arrives — that one is only ever available as the
    /// entry's own `backgroundColor`.
    func calendar(_ colorId: String?) -> String? {
        guard let colorId else { return nil }
        return calendarBackgrounds[colorId]
    }

    /// The palettes in force before — and alongside — any fetch.
    static let googleDefaults = ColorPalette(
        event: currentEvent,
        calendar: currentCalendar
    )

    /// The eleven event colors as Google Calendar itself renders them.
    private static let currentEvent: [String: String] = [
        "1": "#7986cb",  // Lavender
        "2": "#33b679",  // Sage
        "3": "#8e24aa",  // Grape
        "4": "#e67c73",  // Flamingo
        "5": "#f6bf26",  // Banana
        "6": "#f4511e",  // Tangerine
        "7": "#039be5",  // Peacock
        "8": "#616161",  // Graphite
        "9": "#3f51b5",  // Blueberry
        "10": "#0b8043",  // Basil
        "11": "#d50000",  // Tomato
    ]

    /// The twenty-four calendar colors as Google Calendar itself renders them.
    private static let currentCalendar: [String: String] = [
        "1": "#795548",  // Cocoa
        "2": "#e67c73",  // Flamingo
        "3": "#d50000",  // Tomato
        "4": "#f4511e",  // Tangerine
        "5": "#ef6c00",  // Pumpkin
        "6": "#f09300",  // Mango
        "7": "#009688",  // Eucalyptus
        "8": "#0b8043",  // Basil
        "9": "#7cb342",  // Pistachio
        "10": "#c0ca33",  // Avocado
        "11": "#e4c441",  // Citron
        "12": "#f6bf26",  // Banana
        "13": "#33b679",  // Sage
        "14": "#039be5",  // Peacock
        "15": "#4285f4",  // Cobalt
        "16": "#3f51b5",  // Blueberry
        "17": "#7986cb",  // Lavender
        "18": "#b39ddb",  // Wisteria
        "19": "#616161",  // Graphite
        "20": "#a79b8e",  // Birch
        "21": "#ad1457",  // Beetroot
        "22": "#d81b60",  // Cherry Blossom
        "23": "#8e24aa",  // Grape
        "24": "#9e69af",  // Amethyst
    ]
}
