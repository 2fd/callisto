import Testing
import Foundation
@testable import calendar

@Suite("DateHelpers")
struct DateHelpersTests {
    @Test func startOfMinute() {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: 12, minute: 30, second: 45, of: Date.now)!
        let start = date.startOfMinute
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: start)
        #expect(components.hour == 12)
        #expect(components.minute == 30)
        #expect(components.second == 0)
        #expect(components.nanosecond == 0)
    }

    @Test func isToday() {
        #expect(Date.now.isToday)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date.now)!
        #expect(!yesterday.isToday)
    }

    @Test func isTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
        #expect(tomorrow.isTomorrow)
        #expect(!Date.now.isTomorrow)
    }

    @Test func formatUsesProvidedDateFormat() {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        #expect(date.format(f: "yyyy-MM-dd") == "2026-03-01")
    }

    @Test func isAfter() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        #expect(later.isAfter(earlier))
        #expect(!earlier.isAfter(later))
    }

    @Test func isBefore() {
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        #expect(earlier.isBefore(later))
        #expect(!later.isBefore(earlier))
    }
}

@Suite("Date.relative")
struct DateRelativeTests {
    let cal = Calendar.current

    @Test func pastLessThanMinute() {
        let d = Date.now.addingTimeInterval(-30)
        #expect(d.relative() == "less than a minute ago")
    }

    @Test func futureLessThanMinute() {
        let d = Date.now.addingTimeInterval(30)
        #expect(d.relative() == "in less than a minute")
    }

    @Test func exactlyNow() {
        #expect(Date.now.relative() == "less than a minute ago")
    }

    @Test func pastOneMinute() {
        let d = Date.now.addingTimeInterval(-60)
        #expect(d.relative() == "1 minute ago")
    }

    @Test func pastManyMinutes() {
        let d = Date.now.addingTimeInterval(-60 * 5)
        #expect(d.relative() == "5 minutes ago")
    }

    @Test func futureOneMinute() {
        let d = Date.now.addingTimeInterval(65)
        #expect(d.relative() == "in 1 minute")
    }

    @Test func futureManyMinutes() {
        let d = Date.now.addingTimeInterval(60 * 10 + 5)
        #expect(d.relative() == "in 10 minutes")
    }

    @Test func pastOneHourToday() {
        let now = Date.now
        guard cal.component(.hour, from: now) >= 2 else { return }
        let d = now.addingTimeInterval(-3600)
        #expect(d.relative() == "1 hour ago")
    }

    @Test func pastManyHoursToday() {
        let now = Date.now
        guard cal.component(.hour, from: now) >= 4 else { return }
        let d = now.addingTimeInterval(-3600 * 3)
        #expect(d.relative() == "3 hours ago")
    }

    @Test func futureHoursToday() {
        let now = Date.now
        guard cal.component(.hour, from: now) <= 20 else { return }
        let d = now.addingTimeInterval(3600 * 2)
        #expect(d.relative() == "in 2 hours")
    }

    @Test func yesterday() {
        let d = cal.date(byAdding: .day, value: -1, to: Date.now)!
        #expect(d.relative() == "Yesterday")
    }

    @Test func tomorrow() {
        let d = cal.date(byAdding: .day, value: 1, to: Date.now)!
        #expect(d.relative() == "Tomorrow")
    }

    @Test func sameMonthFormat() {
        let now = Date.now
        let dom = cal.component(.day, from: now)
        let offset = dom > 14 ? -10 : 10
        let d = cal.date(byAdding: .day, value: offset, to: now)!
        guard cal.component(.month, from: d) == cal.component(.month, from: now),
              cal.component(.year, from: d) == cal.component(.year, from: now) else { return }

        let s = d.relative()
        #expect(!s.contains(","))
        #expect(s.range(of: #"^[A-Za-z]{3} \d{1,2}$"#, options: .regularExpression) != nil)
    }

    @Test func differentMonthSameYearFormat() {
        let now = Date.now
        let d = cal.date(byAdding: .day, value: 60, to: now)!
        guard cal.component(.year, from: d) == cal.component(.year, from: now),
              cal.component(.month, from: d) != cal.component(.month, from: now) else { return }

        let s = d.relative()
        #expect(s.contains(","))
        #expect(s.range(of: #"^[A-Za-z]{3}, [A-Za-z]{3} \d{1,2}$"#, options: .regularExpression) != nil)
    }

    @Test func differentYearFormat() {
        let d = cal.date(byAdding: .year, value: -2, to: Date.now)!
        let s = d.relative()
        #expect(s.range(of: #"^[A-Za-z]{3}, [A-Za-z]{3} \d{1,2} \d{4}$"#, options: .regularExpression) != nil)
    }
}
