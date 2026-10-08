import Foundation
import Testing
@testable import Zone

struct EmergencyUnlockTests {
    @Test func shortHoldDoesNotStartWait() {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 102.99)
        attempt.releaseHold()
        attempt.advance(at: 400)
        #expect(attempt.phase == .ready)
        let completed1 = attempt.complete(at: 400)
        #expect(!completed1)
    }

    @Test func fullHoldRequiresAnotherThreeMinutes() {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 103)
        attempt.releaseHold()
        #expect(attempt.secondsRemaining(at: 103) == 180)
        #expect(attempt.secondsRemaining(at: 282.1) == 1)
        let completed2 = attempt.complete(at: 282.99)
        #expect(!completed2)
        let completed3 = attempt.complete(at: 283)
        #expect(completed3)
        let completed4 = attempt.complete(at: 284)
        #expect(!completed4)
    }

    @Test func interruptionRequiresBothHoldAndWaitAgain() {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 103)
        attempt.cancel()
        let completed5 = attempt.complete(at: 1000)
        #expect(!completed5)
        attempt.beginHold(at: 1000)
        attempt.advance(at: 1003)
        let completed6 = attempt.complete(at: 1182.99)
        #expect(!completed6)
        let completed7 = attempt.complete(at: 1183)
        #expect(completed7)
    }

    @Test func repeatedInputCannotShortenWait() {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.beginHold(at: 101)
        #expect(attempt.holdProgress(at: 101.5) == 0.5)
        attempt.advance(at: 103)
        attempt.beginHold(at: 200)
        attempt.advance(at: 250)
        #expect(attempt.secondsRemaining(at: 250) == 33)
    }

    @Test func countdownUsesElapsedTimeEvenWhenTicksAreLate() {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 105)
        #expect(attempt.secondsRemaining(at: 105) == 180)
        #expect(attempt.secondsRemaining(at: 200) == 85)
        let completed8 = attempt.complete(at: 290)
        #expect(completed8)
    }

    @Test func allowancePersistsAndRejectsAFourthExit() throws {
        try withDefaults { defaults in
            let now = date(2026, 10, 15)
            let allowance = EmergencyUnlockAllowance(defaults: defaults)
            #expect(allowance.remaining(at: now, calendar: calendar) == 3)
            for _ in 0..<3 { #expect(allowance.consume(at: now, calendar: calendar)) }
            let reloaded = EmergencyUnlockAllowance(defaults: defaults)
            #expect(reloaded.remaining(at: now, calendar: calendar) == 0)
            #expect(!reloaded.consume(at: now, calendar: calendar))
        }
    }

    @Test func allowanceResetsAtTheCalendarMonthBoundary() throws {
        try withDefaults { defaults in
            let allowance = EmergencyUnlockAllowance(defaults: defaults)
            let october = date(2026, 10, 31)
            for _ in 0..<3 { #expect(allowance.consume(at: october, calendar: calendar)) }
            #expect(allowance.remaining(at: date(2026, 11, 1), calendar: calendar) == 3)
            #expect(allowance.consume(at: date(2026, 11, 1), calendar: calendar))
            #expect(allowance.remaining(at: date(2026, 11, 1), calendar: calendar) == 2)
            #expect(allowance.remaining(at: date(2027, 1, 1), calendar: calendar) == 3)
        }
    }

    @Test func movingTheClockBackDoesNotRestoreUses() throws {
        try withDefaults { defaults in
            let allowance = EmergencyUnlockAllowance(defaults: defaults)
            #expect(allowance.consume(at: date(2026, 10, 15), calendar: calendar))
            #expect(allowance.remaining(at: date(2026, 9, 15), calendar: calendar) == 2)
        }
    }

    @MainActor
    @Test func emergencyExitFinishesSessionAndCancelsSuperZoneRelock() throws {
        try withDefaults { defaults in
            let start = Date.now.addingTimeInterval(-600)
            defaults.set(start, forKey: ZoneLock.Keys.zonedSince)
            defaults.set(true, forKey: ZoneLock.Keys.superZone)
            defaults.set(Date.now.addingTimeInterval(900), forKey: ZoneLock.Keys.relockAt)
            let store = ZoneStore(defaults: defaults)
            var attempt = readyAttempt()
            #expect(store.emergencyUnlock(attempt: &attempt, uptime: 283))
            #expect(!store.isZoned)
            #expect(store.relockAt == nil)
            #expect(defaults.object(forKey: ZoneLock.Keys.relockAt) == nil)
            #expect(store.superZone)
            #expect(store.sessions.count == 1)
            #expect(store.sessions.first?.start == start)
            #expect(EmergencyUnlockAllowance(defaults: defaults).remaining(at: .now) == 2)
            #expect(!store.emergencyUnlock(attempt: &attempt, uptime: 284))
            let reloaded = ZoneStore(defaults: defaults)
            #expect(!reloaded.isZoned)
            #expect(reloaded.relockAt == nil)
            #expect(reloaded.sessions.count == 1)
        }
    }

    @MainActor
    @Test func earlyExitAndCancelledWaitDoNotSpendAllowance() throws {
        try withDefaults { defaults in
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            let store = ZoneStore(defaults: defaults)
            var attempt = readyAttempt()
            #expect(!store.emergencyUnlock(attempt: &attempt, uptime: 282.99))
            attempt.cancel()
            #expect(!store.emergencyUnlock(attempt: &attempt, uptime: 500))
            #expect(store.isZoned)
            #expect(store.sessions.isEmpty)
            #expect(EmergencyUnlockAllowance(defaults: defaults).remaining(at: .now) == 3)
        }
    }

    @MainActor
    @Test func exhaustedAllowanceCannotLeaveTheZone() throws {
        try withDefaults { defaults in
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            defaults.set([Date.now, Date.now, Date.now], forKey: EmergencyUnlockAllowance.storageKey)
            let store = ZoneStore(defaults: defaults)
            var attempt = readyAttempt()
            #expect(!store.emergencyUnlock(attempt: &attempt, uptime: 283))
            #expect(store.isZoned)
            #expect(store.sessions.isEmpty)
        }
    }

    @MainActor
    @Test func unlockedStateCannotSpendAllowance() throws {
        try withDefaults { defaults in
            let store = ZoneStore(defaults: defaults)
            var attempt = readyAttempt()
            #expect(!store.emergencyUnlock(attempt: &attempt, uptime: 283))
            #expect(EmergencyUnlockAllowance(defaults: defaults).remaining(at: .now) == 3)
        }
    }

    private func readyAttempt() -> EmergencyUnlockAttempt {
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 103)
        return attempt
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "EmergencyUnlockTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }
}
