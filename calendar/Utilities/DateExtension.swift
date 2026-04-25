import Foundation

let formatters:[String:DateFormatter] = [:]

private let rfc3339Formatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let rfc3339FormatterNoFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

/// Convenience date properties for display and filtering in the event list.
extension Date {
    /// Parses an RFC 3339 string, trying fractional seconds first, then without.
    init?(rfc3339 string: String) {
        if let d = rfc3339Formatter.date(from: string) ?? rfc3339FormatterNoFraction.date(from: string) {
            self = d
        } else {
            return nil
        }
    }

    /// Midnight at the start of this date's day.
    //    var startOfDay: Date {
    //        Calendar.current.startOfDay(for: self)
    //    }
    //
    //    /// Midnight at the start of the next day.
    //    var endOfDay: Date {
    //        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
    //    }
    //
    /// Whether the date falls within today.
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Whether the date falls within tomorrow.
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Start of this date's minute, with seconds and subseconds removed.
    var startOfMinute: Date {
        Calendar.current.dateInterval(of: .minute, for: self)?.start ?? self
    }
    
    static func formatter(f: String) -> DateFormatter {
        if let cached = formatters[f] {
            return cached
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = f
            return formatter
        }
    }
    
    func format(f: String) -> String {
        Self.formatter(f: f).string(from: self)
    }
    
    func relative() -> String {
        let now = Date.now
        let seconds = self.timeIntervalSince(now)
        let past = seconds <= 0
        let absSeconds = abs(seconds)

        if absSeconds < 60 {
            return past ? "less than a minute ago" : "in less than a minute"
        }

        let minutes = Int(absSeconds / 60)
        if minutes < 60 {
            let unit = minutes == 1 ? "minute" : "minutes"
            return past ? "\(minutes) \(unit) ago" : "in \(minutes) \(unit)"
        }

        if isToday {
            let hours = minutes / 60
            let unit = hours == 1 ? "hour" : "hours"
            return past ? "\(hours) \(unit) ago" : "in \(hours) \(unit)"
        }

        let cal = Calendar.current
        if cal.isDateInYesterday(self) { return "Yesterday" }
        if cal.isDateInTomorrow(self) { return "Tomorrow" }

        let selfComps = cal.dateComponents([.year, .month], from: self)
        let nowComps = cal.dateComponents([.year, .month], from: now)

        if selfComps.year != nowComps.year { return format(f: "MMM, EEE d yyyy") }
        if selfComps.month != nowComps.month { return format(f: "MMM, EEE d") }
        return format(f: "EEE d")
    }
    
    func isAfter(_ date: Date) -> Bool {
        self > date
    }
    
    func isBefore(_ date: Date) -> Bool {
        self < date
    }

    /// A human-readable relative label: "Today", "Tomorrow", or a formatted date like "Monday, Mar 24".
//    var relativeDisplay: String {
//        if isToday { return "Today" }
//        if isTomorrow { return "Tomorrow" }
//        return Self.formatter(f: "EEEE, MMM d").string(from: self)
//    }
}

