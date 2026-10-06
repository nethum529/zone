import Foundation
import Testing
@testable import Zone

struct ZoneStatsTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func sessionOverMidnightCountsOnBothDays() {
        let session = ZoneSession(start: date(3, 23), end: date(4, 1))
        let stats = ZoneStats(sessions: [session], now: date(4, 12), calendar: calendar)
        #expect(stats.time(on: date(3, 12)) == 3600)
        #expect(stats.today == 3600)
    }

    @Test func streakCountsDaysInARow() {
        let sessions = [
            ZoneSession(start: date(1, 9), end: date(1, 10)),
            ZoneSession(start: date(3, 9), end: date(3, 10)),
            ZoneSession(start: date(4, 9), end: date(4, 10)),
        ]
        let stats = ZoneStats(sessions: sessions, now: date(4, 12), calendar: calendar)
        #expect(stats.streak == 2)
    }

    @Test func streakKeepsYesterdayWhenTodayIsEmpty() {
        let sessions = [ZoneSession(start: date(3, 9), end: date(3, 10))]
        let stats = ZoneStats(sessions: sessions, now: date(4, 8), calendar: calendar)
        #expect(stats.streak == 1)
    }

    @Test func lastDaysIsOldestFirst() {
        let sessions = [ZoneSession(start: date(4, 9), end: date(4, 9, 30))]
        let days = ZoneStats(sessions: sessions, now: date(4, 12), calendar: calendar).lastDays(7)
        #expect(days.count == 7)
        #expect(days.last?.day == date(4, 0))
        #expect(days.last?.time == 1800)
        #expect(days.dropLast().allSatisfy { $0.time == 0 })
    }

    @Test func monthDaysCoversTheWholeMonth() {
        let sessions = [ZoneSession(start: date(31, 22), end: date(31, 23))]
        let days = ZoneStats(sessions: sessions, now: date(4, 12), calendar: calendar).monthDays()
        #expect(days.count == 31)
        #expect(days.first?.day == date(1, 0))
        #expect(days.last?.time == 3600)
    }
}
