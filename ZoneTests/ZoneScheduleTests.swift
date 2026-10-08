import DeviceActivity
import Darwin
import Foundation
import Testing
@testable import Zone

struct ZoneScheduleTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func schedule(days: Set<Int> = [2, 3, 4, 5, 6], start: Int = 540, end: Int = 1020) -> ZoneSchedule {
        ZoneSchedule(weekdays: days, startMinute: start, endMinute: end, effectiveFrom: date(1, 0))
    }

    @Test func startsOnlyOnChosenDaysAndWithinTimes() {
        let schedule = schedule()
        #expect(schedule.interval(at: date(5, 8, 59), calendar: calendar) == nil)
        #expect(schedule.interval(at: date(5, 9), calendar: calendar)?.end == date(5, 17))
        #expect(schedule.interval(at: date(5, 17), calendar: calendar) == nil)
        #expect(schedule.interval(at: date(4, 10), calendar: calendar) == nil)
    }

    @Test func overnightUsesTheStartWeekdayIncludingSaturdayIntoSunday() {
        let schedule = schedule(days: [7], start: 22 * 60, end: 6 * 60)
        #expect(schedule.interval(at: date(3, 23), calendar: calendar)?.end == date(4, 6))
        #expect(schedule.interval(at: date(4, 5), calendar: calendar)?.start == date(3, 22))
        #expect(schedule.interval(at: date(4, 6), calendar: calendar) == nil)
        #expect(schedule.interval(at: date(4, 23), calendar: calendar) == nil)
    }

    @Test func enablingDuringAnIntervalWaitsForNextStart() {
        var schedule = schedule()
        schedule.effectiveFrom = date(5, 12)
        #expect(schedule.interval(at: date(5, 12), calendar: calendar) == nil)
        #expect(schedule.nextStart(after: date(5, 12), calendar: calendar) == date(6, 9))
        schedule.isEnabled = false
        #expect(schedule.interval(at: date(6, 12), calendar: calendar) == nil)
        #expect(schedule.nextStart(after: date(5, 12), calendar: calendar) == nil)
    }

    @Test(arguments: [(540, 540), (540, 554), (1430, 4)])
    func rejectsIntervalsShorterThanFifteenMinutes(times: (Int, Int)) {
        #expect(schedule(start: times.0, end: times.1).validationMessage != nil)
    }

    @Test func validatesDaysAndAcceptsOvernightMinimum() {
        #expect(schedule(days: []).validationMessage != nil)
        #expect(schedule(days: [8]).validationMessage != nil)
        #expect(schedule(start: 1430, end: 5).validationMessage == nil)
    }

    @Test func endsOnlyTheSessionItStartedAndOnlyOnce() throws {
        let schedule = schedule()
        var state = ZoneScheduleState()
        let started = state.begin(schedule, at: date(5, 9), zonedSince: nil,
                                            canEnter: true, calendar: calendar)
        let run = try #require(started)
        #expect(state.finish(at: date(5, 16), zonedSince: run.zonedSince) == nil)
        #expect(state.finish(at: date(5, 17), zonedSince: run.zonedSince) == run)
        #expect(state.finish(at: date(5, 18), zonedSince: run.zonedSince) == nil)
    }

    @Test func manualZoneAtStartIsNeverOwnedOrEnded() {
        var state = ZoneScheduleState()
        let schedule = schedule()
        #expect(state.begin(schedule, at: date(5, 9), zonedSince: date(5, 8),
                            canEnter: true, calendar: calendar) == nil)
        #expect(state.run == nil)
        #expect(state.finish(at: date(5, 17), zonedSince: date(5, 8)) == nil)
        #expect(state.begin(schedule, at: date(5, 10), zonedSince: nil,
                            canEnter: true, calendar: calendar) == nil)
    }

    @Test func tagExitAndLaterManualSessionSurviveDuplicateCallbacks() throws {
        var state = ZoneScheduleState()
        let schedule = schedule()
        let started = state.begin(schedule, at: date(5, 9), zonedSince: nil,
                                     canEnter: true, calendar: calendar)
        _ = try #require(started)
        state.run = nil
        #expect(state.begin(schedule, at: date(5, 10), zonedSince: nil,
                            canEnter: true, calendar: calendar) == nil)
        #expect(state.finish(at: date(5, 17), zonedSince: date(5, 11)) == nil)
        #expect(state.begin(schedule, at: date(6, 9), zonedSince: nil,
                            canEnter: true, calendar: calendar) != nil)
    }

    @Test func ownershipCannotEndAReplacementSession() throws {
        var state = ZoneScheduleState()
        let started = state.begin(schedule(), at: date(5, 9), zonedSince: nil,
                                     canEnter: true, calendar: calendar)
        _ = try #require(started)
        #expect(state.finish(at: date(5, 17), zonedSince: date(5, 12)) == nil)
        #expect(state.run == nil)
    }

    @Test func overlappingScheduleIsSkippedInsteadOfExtendingTheFirst() throws {
        var state = ZoneScheduleState()
        let started = state.begin(schedule(), at: date(5, 9), zonedSince: nil,
                                              canEnter: true, calendar: calendar)
        let first = try #require(started)
        let overlap = schedule(start: 10 * 60, end: 18 * 60)
        #expect(state.begin(overlap, at: date(5, 10), zonedSince: first.zonedSince,
                            canEnter: true, calendar: calendar) == nil)
        #expect(state.finish(at: date(5, 17), zonedSince: first.zonedSince) == first)
        #expect(state.begin(overlap, at: date(5, 17), zonedSince: nil,
                            canEnter: true, calendar: calendar) == nil)
    }

    @Test func delayedCallbackSkipsAnIntervalThatStartedDuringAFinishedZone() {
        var state = ZoneScheduleState()
        #expect(state.begin(schedule(), at: date(5, 12), zonedSince: nil,
                            canEnter: true, wasZonedAtStart: true, calendar: calendar) == nil)
        #expect(state.run == nil)
    }

    @Test func noTagOrBlockedAppsDoesNotCreateAZone() {
        var state = ZoneScheduleState()
        #expect(state.begin(schedule(), at: date(5, 9), zonedSince: nil,
                            canEnter: false, calendar: calendar) == nil)
    }

    @Test func stateSurvivesAnExtensionRestart() throws {
        let schedule = schedule()
        var state = ZoneScheduleState()
        let started = state.begin(schedule, at: date(5, 9), zonedSince: nil,
                                            canEnter: true, calendar: calendar)
        let run = try #require(started)
        let data = try JSONEncoder().encode(state)
        var restored = try JSONDecoder().decode(ZoneScheduleState.self, from: data)
        #expect(restored.begin(schedule, at: date(5, 10), zonedSince: nil,
                               canEnter: true, calendar: calendar) == nil)
        #expect(restored.finish(at: date(5, 17), zonedSince: run.zonedSince) == run)
    }

    @Test func deviceSchedulesRepeatDailyAndKeepTheRelockSeparate() {
        let schedule = schedule(start: 22 * 60, end: 6 * 60)
        let activity = ZoneScheduleRuntime.activity(for: schedule.id)
        let monitoring = ZoneScheduleRuntime.deviceSchedule(for: schedule)
        #expect(monitoring.repeats)
        #expect(monitoring.intervalStart.hour == 22)
        #expect(monitoring.intervalEnd.hour == 6)
        #expect(ZoneScheduleRuntime.scheduleID(for: activity) == schedule.id)
        #expect(ZoneScheduleRuntime.scheduleID(for: ZoneLock.relockActivity) == nil)
    }

    @Test func springDSTKeepsLocalClockTimes() throws {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = try #require(local.date(from: DateComponents(year: 2027, month: 3, day: 14, hour: 4)))
        var schedule = schedule(days: [1], start: 60, end: 5 * 60)
        schedule.effectiveFrom = .distantPast
        let interval = try #require(schedule.interval(at: now, calendar: local))
        #expect(local.component(.hour, from: interval.start) == 1)
        #expect(local.component(.hour, from: interval.end) == 5)
        #expect(interval.duration == 3 * 3600)
    }

    @Test func aScheduleKeepsItsChosenProfileAndDoesNotReplaceADeletedOne() throws {
        var profiles = ZoneProfiles(first: ZoneProfile(id: UUID(), name: "Focus"))
        let added = profiles.add(named: "Work")
        let work = try #require(added)
        var schedule = schedule()
        schedule.profileID = work
        let restored = try JSONDecoder().decode(ZoneSchedule.self, from: JSONEncoder().encode(schedule))
        #expect(restored.profile(in: profiles)?.id == work)
        #expect(profiles.currentID != work)
        profiles.delete(work)
        #expect(restored.profile(in: profiles) == nil)
    }
}

@MainActor
struct ZoneScheduleStoreTests {
    @Test func emergencyExitClearsScheduledOwnershipAndKeepsTheHandledStart() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let start = Date.now.addingTimeInterval(-600)
        let id = UUID()
        defaults.set(start, forKey: ZoneLock.Keys.zonedSince)
        defaults.set(true, forKey: ZoneLock.Keys.superZone)
        ZoneScheduleRuntime.save(ZoneScheduleState(
            handledStarts: [id: start],
            run: ZoneScheduleRun(scheduleID: id, interval: DateInterval(start: start, duration: 3600),
                                 zonedSince: start)
        ), in: defaults)
        let store = ZoneStore(defaults: defaults)
        #expect(store.scheduleStore.runningID == id)
        var attempt = EmergencyUnlockAttempt()
        attempt.beginHold(at: 100)
        attempt.advance(at: 103)
        #expect(store.emergencyUnlock(attempt: &attempt, uptime: 283))
        let state = ZoneScheduleRuntime.state(in: defaults)
        #expect(state.run == nil)
        #expect(state.handledStarts[id] == start)
        #expect(store.scheduleStore.runningID == nil)
        #expect(!store.isZoned)
        #expect(store.relockAt == nil)
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.start == start)
    }

    @Test func monitorCallsLeaveTheStateLockAvailableToCallbacks() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let group = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nethum.zone"))
        func checkLock() {
            let descriptor = open(group.appendingPathComponent("zone-state.lock").path, O_CREAT | O_RDWR, 0o600)
            #expect(descriptor >= 0)
            defer { close(descriptor) }
            let acquired = flock(descriptor, LOCK_EX | LOCK_NB) == 0
            #expect(acquired)
            if acquired { flock(descriptor, LOCK_UN) }
        }
        let store = ZoneScheduleStore(defaults: defaults,
                                      startMonitoring: { _ in checkLock() }, stopMonitoring: { _ in checkLock() })
        var schedule = ZoneSchedule()
        try store.save(schedule)
        schedule.isEnabled = false
        try store.save(schedule)
        try store.delete(schedule.id)
    }

    @Test func savingUsesTheCurrentProfileUntilTheUserChoosesOne() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var profiles = ZoneProfiles(first: ZoneProfile(id: UUID(), name: "Focus"))
        let focus = profiles.currentID
        let added = profiles.add(named: "Work")
        let work = try #require(added)
        profiles.choose(work)
        profiles.save(to: defaults)
        let store = ZoneScheduleStore(defaults: defaults, startMonitoring: { _ in }, stopMonitoring: { _ in })
        try store.save(ZoneSchedule())
        var saved = try #require(store.schedules.first)
        #expect(saved.profileID == work)
        saved.profileID = focus
        try store.save(saved)
        #expect(ZoneScheduleRuntime.schedules(in: defaults).first?.profileID == focus)
        profiles.delete(focus)
        profiles.save(to: defaults)
        #expect(throws: ScheduleError.self) { try store.save(saved) }
    }

    @Test func aStartDuringRegistrationKeepsTheRunningScheduleAndRestoresItsMonitor() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date.now
        var shouldStart = false
        var registrations: [Int] = []
        let store = ZoneScheduleStore(defaults: defaults, startMonitoring: { schedule in
            registrations.append(schedule.endMinute)
            if shouldStart {
                shouldStart = false
                defaults.set(now, forKey: ZoneLock.Keys.zonedSince)
                ZoneScheduleRuntime.save(ZoneScheduleState(run: ZoneScheduleRun(
                    scheduleID: schedule.id, interval: DateInterval(start: now, duration: 3600), zonedSince: now
                )), in: defaults)
            }
        }, stopMonitoring: { _ in })
        var schedule = ZoneSchedule()
        try store.save(schedule, at: now)
        shouldStart = true
        schedule.endMinute = 18 * 60
        #expect(throws: ScheduleError.self) { try store.save(schedule, at: now) }
        #expect(ZoneScheduleRuntime.schedules(in: defaults).first?.endMinute == 17 * 60)
        #expect(registrations == [17 * 60, 18 * 60, 17 * 60])
        #expect(ZoneScheduleRuntime.state(in: defaults).run?.scheduleID == schedule.id)
    }

    @Test(arguments: [false, true])
    func runtimeUsesTheScheduledProfileOnlyWhenItStartsAZone(alreadyZoned: Bool) throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var profiles = ZoneProfiles(first: ZoneProfile(id: UUID(), name: "Focus"))
        let focus = profiles.currentID
        let added = profiles.add(named: "Work")
        let work = try #require(added)
        profiles.save(to: defaults)
        let start = try #require(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now))
        let schedule = ZoneSchedule(profileID: work, weekdays: Set(1...7), effectiveFrom: .distantPast)
        defaults.set(try JSONEncoder().encode([schedule]), forKey: ZoneScheduleRuntime.schedulesKey)
        if alreadyZoned { defaults.set(start.addingTimeInterval(-3600), forKey: ZoneLock.Keys.zonedSince) }
        var lockedProfile: UUID?
        ZoneScheduleRuntime.reconcile(at: start, defaults: defaults, canEnter: { $0.id == work }, lock: { _ in
            lockedProfile = ZoneProfiles.load(from: defaults).currentID
        }, unlock: { _ in })
        #expect(lockedProfile == (alreadyZoned ? nil : work))
        #expect(ZoneProfiles.load(from: defaults).currentID == (alreadyZoned ? focus : work))
    }

    @Test func runtimeSkipsAnUnavailableScheduledProfileInsteadOfUsingTheCurrentOne() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var profiles = ZoneProfiles(first: ZoneProfile(id: UUID(), name: "Focus"))
        let focus = profiles.currentID
        let added = profiles.add(named: "Work")
        let work = try #require(added)
        profiles.save(to: defaults)
        let start = try #require(Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now))
        let schedule = ZoneSchedule(profileID: work, weekdays: Set(1...7), effectiveFrom: .distantPast)
        defaults.set(try JSONEncoder().encode([schedule]), forKey: ZoneScheduleRuntime.schedulesKey)
        var starts = 0
        ZoneScheduleRuntime.reconcile(at: start, defaults: defaults, canEnter: { $0.id == focus },
                                      lock: { _ in starts += 1 }, unlock: { _ in })
        #expect(starts == 0)
        #expect(ZoneProfiles.load(from: defaults).currentID == focus)
        #expect(ZoneScheduleRuntime.state(in: defaults).handledStarts[schedule.id] == start)
        profiles.delete(work)
        profiles.save(to: defaults)
        defaults.removeObject(forKey: ZoneScheduleRuntime.stateKey)
        ZoneScheduleRuntime.reconcile(at: start, defaults: defaults, canEnter: { _ in true },
                                      lock: { _ in starts += 1 }, unlock: { _ in })
        #expect(starts == 0)
    }

    @Test func scheduleListSortsByStartTime() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let evening = ZoneSchedule(startMinute: 22 * 60, endMinute: 6 * 60)
        let morning = ZoneSchedule()
        defaults.set(try JSONEncoder().encode([evening, morning]), forKey: ZoneScheduleRuntime.schedulesKey)
        let store = ZoneScheduleStore(defaults: defaults, startMonitoring: { _ in }, stopMonitoring: { _ in })
        #expect(store.schedules.map(\.id) == [morning.id, evening.id])
    }

    @Test func runtimeStartsAndEndsWithPersistedOwnership() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let calendar = Calendar.current
        let start = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now))
        let end = try #require(calendar.date(bySettingHour: 17, minute: 0, second: 0, of: .now))
        let schedule = ZoneSchedule(weekdays: Set(1...7), effectiveFrom: .distantPast)
        defaults.set(try JSONEncoder().encode([schedule]), forKey: ZoneScheduleRuntime.schedulesKey)
        defaults.set(true, forKey: ZoneLock.Keys.superZone)
        var starts = 0
        var ends: [Date] = []
        let lock: (Date) -> Void = {
            starts += 1
            defaults.set($0, forKey: ZoneLock.Keys.zonedSince)
        }
        let unlock: (Date) -> Void = {
            ends.append($0)
            defaults.removeObject(forKey: ZoneLock.Keys.zonedSince)
        }
        ZoneScheduleRuntime.reconcile(at: start, defaults: defaults, canEnter: { _ in true }, lock: lock, unlock: unlock)
        #expect(ZoneScheduleRuntime.state(in: defaults).run?.scheduleID == schedule.id)
        ZoneScheduleRuntime.reconcile(at: start, defaults: defaults, canEnter: { _ in true }, lock: lock, unlock: unlock)
        #expect(starts == 1)
        ZoneScheduleRuntime.reconcile(at: end.addingTimeInterval(120), defaults: defaults,
                                      canEnter: { _ in true }, lock: lock, unlock: unlock)
        #expect(ends == [end])
        #expect(ZoneScheduleRuntime.state(in: defaults).run == nil)
        #expect(defaults.object(forKey: ZoneLock.Keys.relockAt) == nil)
    }

    @Test func delayedRuntimeCallbackDoesNotStartOverAFinishedManualSession() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let calendar = Calendar.current
        let nine = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now))
        let schedule = ZoneSchedule(weekdays: Set(1...7), effectiveFrom: .distantPast)
        defaults.set(try JSONEncoder().encode([schedule]), forKey: ZoneScheduleRuntime.schedulesKey)
        let session = ZoneSession(start: nine.addingTimeInterval(-3600), end: nine.addingTimeInterval(3600))
        defaults.set(try JSONEncoder().encode([session]), forKey: ZoneLock.Keys.sessions)
        var starts = 0
        ZoneScheduleRuntime.reconcile(at: nine.addingTimeInterval(7200), defaults: defaults,
                                      canEnter: { _ in true }, lock: { _ in starts += 1 }, unlock: { _ in })
        #expect(starts == 0)
        #expect(ZoneScheduleRuntime.state(in: defaults).handledStarts[schedule.id] == nine)
    }

    @Test func addEditDisableAndDeletePersistAndUpdateTheMonitor() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var starts: [ZoneSchedule] = []
        var stops: [UUID] = []
        let store = ZoneScheduleStore(defaults: defaults,
                                      startMonitoring: { starts.append($0) },
                                      stopMonitoring: { stops.append($0) })
        var schedule = ZoneSchedule()
        try store.save(schedule)
        #expect(store.schedules.count == 1)
        #expect(starts.count == 1)
        schedule.weekdays = [1, 7]
        try store.save(schedule)
        #expect(store.schedules.first?.weekdays == [1, 7])
        #expect(starts.count == 2)
        schedule.isEnabled = false
        try store.save(schedule)
        #expect(stops == [schedule.id])
        let restored = ZoneScheduleRuntime.schedules(in: defaults)
        #expect(restored.first?.isEnabled == false)
        try store.delete(schedule.id)
        #expect(ZoneScheduleRuntime.schedules(in: defaults).isEmpty)
        #expect(stops.count == 2)
    }

    @Test func registrationFailureKeepsThePreviouslySavedSchedule() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var shouldFail = false
        let store = ZoneScheduleStore(defaults: defaults, startMonitoring: { _ in
            if shouldFail { throw ScheduleError(message: "Monitor is full.") }
        }, stopMonitoring: { _ in })
        var schedule = ZoneSchedule()
        try store.save(schedule)
        let before = store.schedules
        shouldFail = true
        schedule.endMinute = 18 * 60
        #expect(throws: ScheduleError.self) { try store.save(schedule) }
        #expect(store.schedules == before)
        #expect(ZoneScheduleRuntime.schedules(in: defaults) == before)
    }

    @Test func editingDisablingOrDeletingARunningScheduleCannotLeaveEarly() throws {
        let name = "schedule-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let now = Date.now
        var schedule = ZoneSchedule()
        defaults.set(now, forKey: ZoneLock.Keys.zonedSince)
        ZoneScheduleRuntime.save(ZoneScheduleState(run: ZoneScheduleRun(
            scheduleID: schedule.id,
            interval: DateInterval(start: now, duration: 3600), zonedSince: now
        )), in: defaults)
        var registrations = 0
        let store = ZoneScheduleStore(defaults: defaults,
                                      startMonitoring: { _ in registrations += 1 },
                                      stopMonitoring: { _ in registrations += 1 })
        #expect(throws: ScheduleError.self) { try store.save(schedule, at: now) }
        schedule.isEnabled = false
        #expect(throws: ScheduleError.self) { try store.save(schedule, at: now) }
        #expect(throws: ScheduleError.self) { try store.delete(schedule.id, at: now) }
        #expect(registrations == 0)
        #expect(defaults.object(forKey: ZoneLock.Keys.zonedSince) as? Date == now)
    }
}
