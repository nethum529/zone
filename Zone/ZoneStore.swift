import FamilyControls
import Foundation
import ManagedSettings
import Observation

// Holds the app state and turns the shields on and off.
// The shields stay on after the app quits, because ManagedSettings keeps them.
@MainActor
@Observable
final class ZoneStore {
    private(set) var authorization: AuthorizationStatus
    private(set) var registeredTagID: String?
    private(set) var zonedSince: Date?
    var selection: FamilyActivitySelection {
        didSet { save(selection, forKey: Keys.selection) }
    }

    var isZoned: Bool { zonedSince != nil }
    var hasBlockedItems: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    private let defaults: UserDefaults
    private let shields = ManagedSettingsStore(named: .init("zone"))

    private enum Keys {
        static let selection = "selection"
        static let tagID = "tagID"
        static let zonedSince = "zonedSince"
    }

    init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults
        authorization = AuthorizationCenter.shared.authorizationStatus
        registeredTagID = defaults.string(forKey: Keys.tagID)
        zonedSince = defaults.object(forKey: Keys.zonedSince) as? Date
        selection = Self.load(FamilyActivitySelection.self, from: defaults, forKey: Keys.selection)
            ?? FamilyActivitySelection()
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
        applyShields()
        setZonedSince(.now)
    }

    func leaveZone() {
        shields.clearAllSettings()
        setZonedSince(nil)
    }

    private func applyShields() {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens
        shields.shield.applications = apps.isEmpty ? nil : apps
        shields.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        shields.shield.webDomains = domains.isEmpty ? nil : domains
        shields.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        // Stop the user from deleting apps to get around the shields.
        shields.application.denyAppRemoval = true
    }

    private func setZonedSince(_ date: Date?) {
        zonedSince = date
        defaults.set(date, forKey: Keys.zonedSince)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
