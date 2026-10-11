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
    private(set) var authorization: AuthorizationStatus
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

    init(defaults: UserDefaults = ZoneLock.defaults) {
        self.defaults = defaults
        scheduleStore = ZoneScheduleStore(defaults: defaults)
        authorization = AuthorizationCenter.shared.authorizationStatus
        superZone = defaults.bool(forKey: Keys.superZone)
        relockMinutes = defaults.object(forKey: Keys.relockMinutes) as? Int ?? 15
        profiles = ZoneProfiles.load(from: defaults)
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

    // iOS loads the Screen Time status a moment after launch.
    // Before that it reports notDetermined, so follow its changes.
    func watchAuthorization() async {
        for await status in AuthorizationCenter.shared.$authorizationStatus.values {
            authorization = status
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Screen Time authorization failed: \(error)")
        }
        authorization = AuthorizationCenter.shared.authorizationStatus
    }

    func registerTag(_ id: String, name: String?) throws {
        try tags.add(id, name: name)
    }

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
