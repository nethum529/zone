import DeviceActivity
import Darwin
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

// The lock state and the shields. The app and the monitor extension both use this.
// The state is in the App Group, so the extension can lock again when the app is not running.
enum ZoneLock {
    static var defaults: UserDefaults { UserDefaults(suiteName: "group.com.nethum.zone")! }
    static var shields: ManagedSettingsStore { ManagedSettingsStore(named: .init("zone")) }

    // In Super Zone, the extension locks again when this activity starts.
    static var relockActivity: DeviceActivityName { DeviceActivityName("relock") }

    enum Keys {
        // Before profiles, the one selection. Kept so the first profile can be made from it.
        static let selection = "selection"
        static let profiles = "profiles"
        // Before the tag list, the one main tag. Kept so the list can be made from it.
        static let tagID = "tagID"
        static let tags = "tags"
        static let zonedSince = "zonedSince"
        static let superZone = "superZone"
        static let relockAt = "relockAt"
        static let relockMinutes = "relockMinutes"
        static let sessions = "sessions"
        #if DEBUG
        static let replaySetup = "debugReplaySetup"
        #endif
    }

    static var profiles: ZoneProfiles { ZoneProfiles.load(from: defaults) }

    // The apps of the current profile. A relock uses this, so it locks the last used profile.
    static var selection: FamilyActivitySelection { profiles.current.selection }

    // A new lock can choose a profile. An existing Zone keeps its profile.
    static func lock(profile id: ZoneProfile.ID? = nil, in defaults: UserDefaults = ZoneLock.defaults) {
        withStateLock {
            #if DEBUG
            guard !defaults.bool(forKey: Keys.replaySetup) else { return }
            #endif
            guard defaults.object(forKey: Keys.zonedSince) == nil else { return }
            if let id {
                var profiles = ZoneProfiles.load(from: defaults)
                profiles.choose(id)
                profiles.save(to: defaults)
            }
            var state = ZoneScheduleRuntime.state(in: defaults)
            state.run = nil
            ZoneScheduleRuntime.save(state, in: defaults)
            applyLock(at: .now, in: defaults)
        }
    }

    static func applyLock(at now: Date, in defaults: UserDefaults = ZoneLock.defaults) {
        let profile = ZoneProfiles.load(from: defaults).current
        let selection = profile.selection
        let shields = shields
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens
        shields.shield.applications = apps.isEmpty ? nil : apps
        shields.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        shields.shield.webDomains = domains.isEmpty ? nil : domains
        shields.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        // Typed sites have no tokens, so the shield cannot show them. The web filter blocks them instead.
        let sites = Set(profile.sites.map { WebDomain(domain: $0) })
        shields.webContent.blockedByFilter = sites.isEmpty ? nil : .specific(sites)
        defaults.set(now, forKey: Keys.zonedSince)
        defaults.removeObject(forKey: Keys.relockAt)
        removeReminder()
    }

    // The app's reminder to enter the Zone again. See Zone/ZoneReminder.swift.
    static let reminderID = "reminder"

    static func removeReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        center.removeDeliveredNotifications(withIdentifiers: [reminderID])
    }

    @discardableResult
    static func relockIfNeeded(
        at now: Date = .now, tolerance: TimeInterval = 0,
        in defaults: UserDefaults = ZoneLock.defaults
    ) -> Bool {
        withStateLock {
            #if DEBUG
            guard !defaults.bool(forKey: Keys.replaySetup) else { return false }
            #endif
            guard defaults.bool(forKey: Keys.superZone),
                defaults.object(forKey: Keys.zonedSince) == nil,
                let relockAt = defaults.object(forKey: Keys.relockAt) as? Date,
                relockAt <= now || relockAt.timeIntervalSince(now) < tolerance
            else { return false }
            var state = ZoneScheduleRuntime.state(in: defaults)
            state.run = nil
            ZoneScheduleRuntime.save(state, in: defaults)
            applyLock(at: now, in: defaults)
            return true
        }
    }

    static func unlock(in defaults: UserDefaults = ZoneLock.defaults) {
        withStateLock {
            applyUnlock(at: .now, in: defaults)
            var state = ZoneScheduleRuntime.state(in: defaults)
            state.run = nil
            ZoneScheduleRuntime.save(state, in: defaults)
        }
    }

    static func applyUnlock(at end: Date, in defaults: UserDefaults = ZoneLock.defaults) {
        if let start = defaults.object(forKey: Keys.zonedSince) as? Date {
            var sessions = defaults.data(forKey: Keys.sessions)
                .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
            sessions.append(ZoneSession(start: start, end: max(start, end)))
            defaults.set(try? JSONEncoder().encode(sessions), forKey: Keys.sessions)
        }
        shields.clearAllSettings()
        defaults.removeObject(forKey: Keys.zonedSince)
    }

    // The app and extension must not change session ownership at the same time.
    static func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nethum.zone")!
        let descriptor = open(directory.appendingPathComponent("zone-state.lock").path, O_CREAT | O_RDWR, 0o600)
        precondition(descriptor >= 0, "Could not open the Zone state lock")
        defer { close(descriptor) }
        precondition(flock(descriptor, LOCK_EX) == 0, "Could not lock the Zone state")
        defaults.synchronize()
        defer {
            defaults.synchronize()
            flock(descriptor, LOCK_UN)
        }
        return try body()
    }
}
