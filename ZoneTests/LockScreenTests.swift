import Foundation
import Testing
@testable import Zone

struct ZoneSnapshotTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func todayCountsTheCurrentSession() {
        let snapshot = ZoneSnapshot(
            zonedSince: date(7, 11),
            sessions: [ZoneSession(start: date(7, 8), end: date(7, 9))]
        )
        #expect(snapshot.today(at: date(7, 11, 30), calendar: calendar) == 5400)
    }

    @Test func todayStartsAgainAtMidnight() {
        let snapshot = ZoneSnapshot(zonedSince: date(6, 23), sessions: [])
        #expect(snapshot.today(at: date(7, 0, 30), calendar: calendar) == 1800)
    }

    @Test func relockEntersTheZoneAtItsTime() {
        let snapshot = ZoneSnapshot(relockAt: date(7, 12), sessions: [])
        #expect(!snapshot.at(date(7, 11, 59)).isZoned)
        #expect(snapshot.at(date(7, 12)).zonedSince == date(7, 12))
        #expect(snapshot.at(date(7, 12, 30)).today(at: date(7, 12, 30), calendar: calendar) == 1800)
    }

    @Test func changesAtMidnightAndAtTheRelock() {
        let relock = ZoneSnapshot(relockAt: date(7, 12), sessions: [])
        #expect(relock.changes(after: date(7, 11), calendar: calendar) == [date(7, 12), date(8, 0)])
        let zoned = ZoneSnapshot(zonedSince: date(7, 9), sessions: [])
        #expect(zoned.changes(after: date(7, 11), calendar: calendar) == [date(8, 0)])
    }

    // The widget reads the keys that the app writes.
    @Test func loadReadsTheAppState() throws {
        let defaults = try #require(UserDefaults(suiteName: "ZoneSnapshotTests-\(UUID())"))
        let sessions = [ZoneSession(start: date(7, 8), end: date(7, 9))]
        defaults.set(date(7, 11), forKey: ZoneLock.Keys.zonedSince)
        defaults.set(date(7, 13), forKey: ZoneLock.Keys.relockAt)
        defaults.set(try JSONEncoder().encode(sessions), forKey: ZoneLock.Keys.sessions)
        let snapshot = ZoneSnapshot.load(from: defaults)
        #expect(snapshot == ZoneSnapshot(zonedSince: date(7, 11), relockAt: date(7, 13), sessions: sessions))
    }
}

struct LockScreenSyncTests {
    let since = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func startsWhenInTheZoneWithNoActivity() {
        let plan = LockScreenSync.plan(zonedSince: since, activities: [])
        #expect(plan == LockScreenSync.Plan(end: [], start: true))
    }

    @Test func keepsTheActivityOfThisSession() {
        let old = since.addingTimeInterval(-3600)
        let plan = LockScreenSync.plan(zonedSince: since, activities: [(old, true), (since, true)])
        #expect(plan == LockScreenSync.Plan(end: [0], start: false))
    }

    // iOS ends an activity after 8 hours. The session is still on, so start a new one.
    @Test func replacesAnActivityThatIOSEnded() {
        let plan = LockScreenSync.plan(zonedSince: since, activities: [(since, false)])
        #expect(plan == LockScreenSync.Plan(end: [0], start: true))
    }

    @Test func endsAllWhenNotInTheZone() {
        let plan = LockScreenSync.plan(zonedSince: nil, activities: [(since, true), (since, false)])
        #expect(plan == LockScreenSync.Plan(end: [0, 1], start: false))
    }
}
