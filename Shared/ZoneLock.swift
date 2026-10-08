import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

// The lock state and the shields. The app and the monitor extension both use this.
// The state is in the App Group, so the extension can lock again when the app is not running.
enum ZoneLock {
    static var defaults: UserDefaults { UserDefaults(suiteName: "group.com.nethum.zone")! }
    static var shields: ManagedSettingsStore { ManagedSettingsStore(named: .init("zone")) }

    // In Super Zone, the extension locks again when this activity ends.
    static var relockActivity: DeviceActivityName { DeviceActivityName("relock") }

    enum Keys {
        // Before profiles, the one selection. Kept so the first profile can be made from it.
        static let selection = "selection"
        static let profiles = "profiles"
        static let tagID = "tagID"
        static let zonedSince = "zonedSince"
        static let superZone = "superZone"
        static let relockAt = "relockAt"
        static let relockMinutes = "relockMinutes"
        static let sessions = "sessions"
    }

    static var profiles: ZoneProfiles { ZoneProfiles.load(from: defaults) }

    // The apps of the current profile. A relock uses this, so it locks the last used profile.
    static var selection: FamilyActivitySelection { profiles.current.selection }

    // Makes this profile current, then locks. An unknown id keeps the current profile.
    static func lock(profile id: ZoneProfile.ID) {
        var profiles = profiles
        profiles.choose(id)
        profiles.save(to: defaults)
        lock()
    }

    static func lock() {
        let selection = selection
        let shields = shields
        let defaults = defaults
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens
        shields.shield.applications = apps.isEmpty ? nil : apps
        shields.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        shields.shield.webDomains = domains.isEmpty ? nil : domains
        shields.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        defaults.set(Date.now, forKey: Keys.zonedSince)
        defaults.removeObject(forKey: Keys.relockAt)
    }
}
