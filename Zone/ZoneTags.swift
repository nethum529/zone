import Foundation
import Observation

enum ZoneTagError: LocalizedError, Equatable {
    case verificationRequired
    case alreadyRegistered
    case mainTagRequired
    case emptyTag

    var errorDescription: String? {
        switch self {
        case .verificationRequired: "Scan a saved tag before making changes."
        case .alreadyRegistered: "This tag is already saved. Scan a different tag."
        case .mainTagRequired: "Register your main tag first."
        case .emptyTag: "Could not read the tag. Try again."
        }
    }
}

// Keeps the original main tag key so existing tags still work.
@MainActor
@Observable
final class ZoneTags {
    private(set) var mainID: String?
    private(set) var backupID: String?
    // Names the user gives the tags, like Desk or Keychain.
    private(set) var mainName: String?
    private(set) var backupName: String?

    private let defaults: UserDefaults
    private static let backupKey = "backupTagID"
    private static let mainNameKey = "mainTagName"
    private static let backupNameKey = "backupTagName"

    init(defaults: UserDefaults = ZoneLock.defaults) {
        self.defaults = defaults
        mainID = defaults.string(forKey: ZoneLock.Keys.tagID)
        backupID = defaults.string(forKey: Self.backupKey)
        mainName = defaults.string(forKey: Self.mainNameKey)
        backupName = defaults.string(forKey: Self.backupNameKey)
    }

    // An empty name removes the name.
    func setName(_ name: String, backup: Bool) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = backup ? Self.backupNameKey : Self.mainNameKey
        if name.isEmpty { defaults.removeObject(forKey: key) } else { defaults.set(name, forKey: key) }
        if backup { backupName = name.isEmpty ? nil : name } else { mainName = name.isEmpty ? nil : name }
    }

    var requiresVerification: Bool {
        defaults.object(forKey: ZoneLock.Keys.zonedSince) != nil
            || defaults.object(forKey: ZoneLock.Keys.relockAt) != nil
    }

    func contains(_ id: String) -> Bool {
        !id.isEmpty && (id == mainID || id == backupID)
    }

    func setMain(_ id: String, verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        try validateNewTag(id)
        defaults.set(id, forKey: ZoneLock.Keys.tagID)
        mainID = id
    }

    func setBackup(_ id: String, verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        guard mainID != nil else { throw ZoneTagError.mainTagRequired }
        try validateNewTag(id)
        defaults.set(id, forKey: Self.backupKey)
        backupID = id
    }

    func removeBackup(verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        defaults.removeObject(forKey: Self.backupKey)
        backupID = nil
        setName("", backup: true)
    }

    private func validateChange(verifiedBy savedID: String?) throws {
        // Read the current lock state again after each scan.
        if requiresVerification, savedID.map(contains) != true {
            throw ZoneTagError.verificationRequired
        }
    }

    private func validateNewTag(_ id: String) throws {
        guard !id.isEmpty else { throw ZoneTagError.emptyTag }
        guard !contains(id) else { throw ZoneTagError.alreadyRegistered }
    }
}
