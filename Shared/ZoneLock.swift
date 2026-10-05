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
        static let selection = "selection"
        static let tagID = "tagID"
        static let zonedSince = "zonedSince"
        static let superZone = "superZone"
        static let relockAt = "relockAt"
        static let relockMinutes = "relockMinutes"
        static let sessions = "sessions"
    }

    static var selection: FamilyActivitySelection {
        guard let data = defaults.data(forKey: Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return selection
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
