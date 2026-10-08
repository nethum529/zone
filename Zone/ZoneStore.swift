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
    var registeredTagID: String? { tags.mainID }
    private(set) var zonedSince: Date?
    // In Super Zone, the time when Zone locks again after the user leaves.
    private(set) var relockAt: Date?
    // Finished sessions, oldest first.
    private(set) var sessions: [ZoneSession]
    var superZone: Bool {
        didSet { defaults.set(superZone, forKey: Keys.superZone) }
    }
    // iOS does not monitor an activity shorter than 15 minutes.
    static let relockChoices = [15, 30, 45, 60, 90, 120]
    var relockMinutes: Int {
        didSet { defaults.set(relockMinutes, forKey: Keys.relockMinutes) }
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
    // In the Zone, the current profile cannot change.
    // While Zone waits to lock again, a new choice is the profile the relock uses.
    var isLocked: Bool { isZoned }
    var hasBlockedItems: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    private typealias Keys = ZoneLock.Keys
    private let defaults: UserDefaults
    private let activityCenter = DeviceActivityCenter()

    init(defaults: UserDefaults = ZoneLock.defaults) {
        self.defaults = defaults
        scheduleStore = ZoneScheduleStore(defaults: defaults)
        authorization = AuthorizationCenter.shared.authorizationStatus
        superZone = defaults.bool(forKey: Keys.superZone)
        relockMinutes = defaults.object(forKey: Keys.relockMinutes) as? Int ?? Self.relockChoices[0]
        profiles = ZoneProfiles.load(from: defaults)
        sessions = defaults.data(forKey: Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        refresh()
    }

    // Reads the lock state again, because the monitor extension can change it.
    // If the relock time passed and the extension did not lock, lock now.
    func refresh() {
        ZoneScheduleRuntime.reconcile(in: defaults)
        scheduleStore.refresh()
        sessions = defaults.data(forKey: Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        zonedSince = defaults.object(forKey: Keys.zonedSince) as? Date
        relockAt = defaults.object(forKey: Keys.relockAt) as? Date
        let saved = ZoneProfiles.load(from: defaults)
        if saved != profiles { profiles = saved }
        if !isZoned, let relockAt, relockAt <= .now {
            enterZone()
        }
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

    func registerTag(_ id: String) throws {
        try tags.setMain(id)
    }

    func isRegisteredTag(_ id: String) -> Bool {
        tags.contains(id)
    }

    func enterZone() {
        activityCenter.stopMonitoring([ZoneLock.relockActivity])
        ZoneLock.lock(in: defaults)
        refresh()
    }

    // The finished sessions and the current one up to now.
    func sessions(at now: Date) -> [ZoneSession] {
        guard let zonedSince else { return sessions }
        return sessions + [ZoneSession(start: zonedSince, end: now)]
    }

    func leaveZone(allowRelock: Bool = true) {
        guard isZoned else { return }
        defaults.removeObject(forKey: Keys.relockAt)
        activityCenter.stopMonitoring([ZoneLock.relockActivity])
        ZoneLock.unlock(in: defaults)
        if superZone && allowRelock {
            scheduleRelock()
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

    private func scheduleRelock() {
        let start = Date.now
        let end = start.addingTimeInterval(TimeInterval(relockMinutes * 60))
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false
        )
        let shouldMonitor = ZoneLock.withStateLock {
            guard defaults.object(forKey: Keys.zonedSince) == nil else { return false }
            defaults.set(end, forKey: Keys.relockAt)
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
