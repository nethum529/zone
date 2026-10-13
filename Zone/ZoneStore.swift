import DeviceActivity
import FamilyControls
import Foundation
import Observation

// Holds the app state and turns the shields on and off.
// The shields stay on after the app quits, because ManagedSettings keeps them.
@MainActor
@Observable
final class ZoneStore {
    let scheduleStore: ZoneScheduleStore
    private(set) var authorization: AuthorizationStatus = .notDetermined
    private(set) var isRequestingAuthorization = false
    private(set) var authorizationError: String?
    var hasScreenTimeAccess: Bool { authorization == .approved && authorizationError == nil }
    let tags = ZoneTags()
    var hasTag: Bool { !tags.all.isEmpty }
    private(set) var zonedSince: Date?
    // In Super Zone, the time when Zone locks again after the user leaves.
    private(set) var relockAt: Date?
    // Finished sessions, oldest first.
    private(set) var sessions: [ZoneSession]
    var superZone: Bool {
        didSet {
            ZoneLock.withStateLock { defaults.set(superZone, forKey: Keys.superZone) }
            if !superZone {
                cancelRelock()
                refresh()
                // Out of the Zone, nothing locks again now, so remind the user.
                if !isZoned { Task { await ZoneReminder.shared.schedule() } }
            } else {
                ZoneLock.removeReminder()
            }
        }
    }
    static let relockChoices = [5, 10, 15, 30, 45, 60, 90, 120]
    var relockMinutes: Int {
        didSet {
            defaults.set(relockMinutes, forKey: Keys.relockMinutes)
            if relockMinutes != oldValue, superZone, relockAt != nil {
                // A new duration starts a new wait.
                cancelRelock()
                scheduleRelock()
                refresh()
            }
        }
    }
    var profiles: ZoneProfiles {
        didSet { profiles.save(to: defaults) }
    }
    // The apps of the current profile.
    var selection: FamilyActivitySelection {
        get { profiles.current.selection }
        set { profiles.setSelection(newValue, for: profiles.currentID) }
    }

    var isZoned: Bool { zonedSince != nil }
    // In the Zone the profile cannot change, and the profile in use cannot lose apps or be deleted.
    var isLocked: Bool { isZoned }
    var hasBlockedItems: Bool { profiles.current.blocksSomething }

    private typealias Keys = ZoneLock.Keys
    private let defaults: UserDefaults
    private let activityCenter = DeviceActivityCenter()
    private var requestedAuthorization = false
    #if DEBUG
    private(set) var isReplayingSetup: Bool
    #endif

    init(defaults: UserDefaults = ZoneLock.defaults) {
        self.defaults = defaults
        scheduleStore = ZoneScheduleStore(defaults: defaults)
        superZone = defaults.bool(forKey: Keys.superZone)
        relockMinutes = defaults.object(forKey: Keys.relockMinutes) as? Int ?? 15
        profiles = ZoneProfiles.load(from: defaults)
        #if DEBUG
        isReplayingSetup = defaults.bool(forKey: Keys.replaySetup)
        #endif
        sessions = defaults.data(forKey: Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        refresh()
    }

    // Reads the lock state again, because the monitor extension can change it.
    // If the relock time passed and the extension did not lock, lock now.
    func refresh() {
        ZoneScheduleRuntime.reconcile(in: defaults)
        if ZoneLock.relockIfNeeded(tolerance: 0, in: defaults) {
            activityCenter.stopMonitoring([ZoneLock.relockActivity])
        }
        scheduleStore.refresh()
        sessions = defaults.data(forKey: Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        zonedSince = defaults.object(forKey: Keys.zonedSince) as? Date
        relockAt = defaults.object(forKey: Keys.relockAt) as? Date
        let saved = ZoneProfiles.load(from: defaults)
        if saved != profiles { profiles = saved }
    }

    // Read Screen Time after the first page can appear, not in the app's initializer.
    // iOS loads the Screen Time status a moment after launch.
    // Before that it reports notDetermined, so follow its changes.
    func watchAuthorization() async {
        for await status in AuthorizationCenter.shared.$authorizationStatus.values {
            if status != authorization, status == .approved { authorizationError = nil }
            authorization = status
            // A reinstall can keep the grant. Refresh it before using the picker or shields.
            if status == .approved, !hasTag, !requestedAuthorization {
                await requestAuthorization()
            }
        }
    }

    func requestAuthorization() async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        requestedAuthorization = true
        authorizationError = nil
        defer { isRequestingAuthorization = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Screen Time authorization failed: \(error)")
            authorizationError = "Could not allow Screen Time access. Try again."
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
        if authorization != .approved, authorizationError == nil {
            authorizationError = "Screen Time access was not allowed. Try again."
        }
    }

    func registerTag(_ id: String, name: String?) throws {
        #if DEBUG
        if isReplayingSetup, tags.contains(id) {
            if let name { tags.rename(id, to: name) }
            return
        }
        #endif
        try tags.add(id, name: name)
    }

    #if DEBUG
    func replaySetup() throws {
        guard !isRequestingAuthorization else { return }
        refresh()
        let started = ZoneLock.withStateLock {
            guard defaults.object(forKey: Keys.zonedSince) == nil else { return false }
            defaults.set(true, forKey: Keys.replaySetup)
            return true
        }
        guard started else { throw ScheduleError(message: "Leave the Zone to replay setup.") }
        // Keep Screen Time access. Revoking it voids every saved app token.
        isReplayingSetup = true
        activityCenter.stopMonitoring()
        cancelRelock()
        ZoneLock.shields.clearAllSettings()
        ZoneLock.removeReminder()
    }

    func finishReplay() throws {
        guard hasScreenTimeAccess else {
            throw ScheduleError(message: "Allow Screen Time access before you continue.")
        }
        try restoreReplayMonitoring()
        enterZone()
    }

    private func restoreReplayMonitoring() throws {
        // Keep callbacks paused until every saved monitor has been restored.
        for schedule in ZoneScheduleRuntime.schedules(in: defaults) where schedule.isEnabled {
            try activityCenter.startMonitoring(
                ZoneScheduleRuntime.activity(for: schedule.id),
                during: ZoneScheduleRuntime.deviceSchedule(for: schedule)
            )
        }
        ZoneLock.withStateLock { defaults.removeObject(forKey: Keys.replaySetup) }
        isReplayingSetup = false
    }
    #endif

    func isRegisteredTag(_ id: String) -> Bool {
        tags.contains(id)
    }

    func enterZone() {
        activityCenter.stopMonitoring([ZoneLock.relockActivity])
        ZoneLock.lock(in: defaults)
        refresh()
    }

    // In the Zone the profile cannot change. While Zone waits to lock again, the relock uses the new choice.
    func chooseProfile(_ id: ZoneProfile.ID) {
        ZoneLock.withStateLock {
            var profiles = ZoneProfiles.load(from: defaults)
            guard defaults.object(forKey: Keys.zonedSince) == nil,
                profiles.profile(id) != nil, profiles.currentID != id
            else { return }
            profiles.choose(id)
            profiles.save(to: defaults)
        }
        refresh()
    }

    // The finished sessions and the current one up to now.
    func sessions(at now: Date) -> [ZoneSession] {
        guard let zonedSince else { return sessions }
        return sessions + [ZoneSession(start: zonedSince, end: now)]
    }

    func leaveZone(allowRelock: Bool = true) {
        guard isZoned else { return }
        cancelRelock()
        ZoneLock.unlock(in: defaults)
        if superZone && allowRelock {
            scheduleRelock()
        } else if !superZone {
            Task { await ZoneReminder.shared.schedule() }
        }
        refresh()
    }

    func emergencyUnlock(
        attempt: inout EmergencyUnlockAttempt,
        uptime: TimeInterval,
        now: Date = .now
    ) -> Bool {
        guard isZoned else { return false }
        let allowance = EmergencyUnlockAllowance(defaults: defaults)
        guard allowance.remaining(at: now) > 0,
              attempt.complete(at: uptime),
              allowance.consume(at: now) else { return false }
        leaveZone(allowRelock: false)
        return true
    }

    private func cancelRelock() {
        ZoneLock.withStateLock { defaults.removeObject(forKey: Keys.relockAt) }
        activityCenter.stopMonitoring([ZoneLock.relockActivity])
    }

    // iOS does not monitor an activity shorter than 15 minutes, so the activity starts at the relock time.
    // The monitor extension locks when the activity starts. The end is a second chance.
    private func scheduleRelock() {
        let start = Date.now.addingTimeInterval(TimeInterval(relockMinutes * 60))
        let end = start.addingTimeInterval(15 * 60)
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false
        )
        let shouldMonitor = ZoneLock.withStateLock {
            guard defaults.bool(forKey: Keys.superZone),
                defaults.object(forKey: Keys.zonedSince) == nil
            else { return false }
            defaults.set(start, forKey: Keys.relockAt)
            return true
        }
        guard shouldMonitor else { return }
        do {
            try activityCenter.startMonitoring(ZoneLock.relockActivity, during: schedule)
        } catch {
            // refresh() still locks the next time the app opens.
            print("Could not schedule the relock: \(error)")
        }
    }
}
