import Foundation
import Observation

enum ZoneTagError: LocalizedError, Equatable {
    case verificationRequired
    case alreadyRegistered
    case lastTag
    case emptyTag

    var errorDescription: String? {
        switch self {
        case .verificationRequired: "Scan a saved tag before making changes."
        case .alreadyRegistered: "This tag is already saved. Scan a different tag."
        case .lastTag: "Keep at least one tag, so you can leave the Zone."
        case .emptyTag: "Could not read the tag. Try again."
        }
    }
}

// The saved tags. The first saved tags come from the old main and backup tag keys.
@MainActor
@Observable
final class ZoneTags {
    private(set) var all: [ZoneTag]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = ZoneLock.defaults) {
        self.defaults = defaults
        all = ZoneTag.load(from: defaults)
    }

    func tag(_ id: ZoneTag.ID) -> ZoneTag? {
        all.first { $0.id == id }
    }

    // The tag's name, or its place in the list when it has no name.
    func title(_ id: ZoneTag.ID) -> String {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return "Tag" }
        return all[index].name ?? "Tag \(index + 1)"
    }

    // An empty name removes the name.
    func rename(_ id: ZoneTag.ID, to name: String) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        all[index].name = name.isEmpty ? nil : name
        save()
    }

    var requiresVerification: Bool {
        defaults.object(forKey: ZoneLock.Keys.zonedSince) != nil
            || defaults.object(forKey: ZoneLock.Keys.relockAt) != nil
    }

    func contains(_ id: String) -> Bool {
        !id.isEmpty && tag(id) != nil
    }

    func add(_ id: String, name: String? = nil, verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        try validateNewTag(id)
        all.append(ZoneTag(id: id))
        if let name { rename(id, to: name) } else { save() }
    }

    // The new tag keeps the old tag's name and place.
    func replace(_ oldID: ZoneTag.ID, with id: String, verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        try validateNewTag(id)
        guard let index = all.firstIndex(where: { $0.id == oldID }) else { return }
        all[index] = ZoneTag(id: id, name: all[index].name)
        save()
    }

    func delete(_ id: ZoneTag.ID, verifiedBy savedID: String? = nil) throws {
        try validateChange(verifiedBy: savedID)
        guard all.count > 1 else { throw ZoneTagError.lastTag }
        all.removeAll { $0.id == id }
        save()
    }

    private func save() {
        ZoneTag.save(all, to: defaults)
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
