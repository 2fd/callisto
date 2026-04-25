import Testing
import Foundation
@testable import calendar

@Suite("DateHelpers")
struct DateHelpersTests {
    @Test func startOfDay() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: Date.now)!
        let start = noon.startOfDay
        let components = calendar.dateComponents([.hour, .minute, .second], from: start)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test func endOfDay() {
        let calendar = Calendar.current
        let today = Date.now.startOfDay
        let end = today.endOfDay
        let expected = calendar.date(byAdding: .day, value: 1, to: today)!
        #expect(end == expected)
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

    @Test func relativeDisplayToday() {
        #expect(Date.now.relativeDisplay == "Today")
    }

    @Test func relativeDisplayTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date.now)!
        #expect(tomorrow.relativeDisplay == "Tomorrow")
    }

    @Test func relativeDisplayFutureDate() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date.now)!
        let display = future.relativeDisplay
        #expect(display != "Today")
        #expect(display != "Tomorrow")
        #expect(display.contains(","))
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
        let d = Date.now.addingTimeInterval(60)
        #expect(d.relative() == "in 1 minute")
    }

    @Test func futureManyMinutes() {
        let d = Date.now.addingTimeInterval(60 * 10)
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
