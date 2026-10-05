import DeviceActivity
import FamilyControls
import Foundation
import Observation

// Holds the app state and turns the shields on and off.
// The shields stay on after the app quits, because ManagedSettings keeps them.
@MainActor
@Observable
final class ZoneStore {
    private(set) var authorization: AuthorizationStatus
    private(set) var registeredTagID: String?
    private(set) var zonedSince: Date?
    // In Super Zone, the time when Zone locks again after the user leaves.
    private(set) var relockAt: Date?
    // Finished sessions, oldest first.
    private(set) var sessions: [ZoneSession]
    var superZone: Bool {
        didSet { defaults.set(superZone, forKey: Keys.superZone) }
    }
    var selection: FamilyActivitySelection {
        didSet { defaults.set(try? JSONEncoder().encode(selection), forKey: Keys.selection) }
    }

    var isZoned: Bool { zonedSince != nil }
    var hasBlockedItems: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    private typealias Keys = ZoneLock.Keys
    private let defaults = ZoneLock.defaults
    private let activityCenter = DeviceActivityCenter()

    init() {
        authorization = AuthorizationCenter.shared.authorizationStatus
        registeredTagID = defaults.string(forKey: Keys.tagID)
        superZone = defaults.bool(forKey: Keys.superZone)
        selection = ZoneLock.selection
        sessions = defaults.data(forKey: Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        refresh()
    }

    // Reads the lock state again, because the monitor extension can change it.
    // If the relock time passed and the extension did not lock, lock now.
    func refresh() {
        zonedSince = defaults.object(forKey: Keys.zonedSince) as? Date
        relockAt = defaults.object(forKey: Keys.relockAt) as? Date
        if !isZoned, let relockAt, relockAt <= .now {
            enterZone()
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

    func registerTag(_ id: String) {
        registeredTagID = id
        defaults.set(id, forKey: Keys.tagID)
    }

    func isRegisteredTag(_ id: String) -> Bool {
        id == registeredTagID
    }

    func enterZone() {
        activityCenter.stopMonitoring([ZoneLock.relockActivity])
        ZoneLock.lock()
        refresh()
    }

    // The finished sessions and the current one up to now.
    func sessions(at now: Date) -> [ZoneSession] {
        guard let zonedSince else { return sessions }
        return sessions + [ZoneSession(start: zonedSince, end: now)]
    }

    func leaveZone() {
        if let zonedSince {
            sessions.append(ZoneSession(start: zonedSince, end: .now))
            defaults.set(try? JSONEncoder().encode(sessions), forKey: Keys.sessions)
        }
        ZoneLock.shields.clearAllSettings()
        defaults.removeObject(forKey: Keys.zonedSince)
        if superZone {
            scheduleRelock()
        }
        refresh()
    }

    private func scheduleRelock() {
        let start = Date.now
        let end = start.addingTimeInterval(ZoneLock.relockDelay)
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents(parts, from: start),
            intervalEnd: Calendar.current.dateComponents(parts, from: end),
            repeats: false
        )
        defaults.set(end, forKey: Keys.relockAt)
        do {
            try activityCenter.startMonitoring(ZoneLock.relockActivity, during: schedule)
        } catch {
            // refresh() still locks the next time the app opens.
            print("Could not schedule the relock: \(error)")
        }
    }
}
