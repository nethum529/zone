import FamilyControls
import Foundation

// A named set of blocked apps and websites, for example Work or Sleep.
// The id never changes, so other features (such as schedules) can point to a profile.
struct ZoneProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var selection = FamilyActivitySelection()
}

// All profiles and the current one. There is always at least one profile.
// The current profile is the one Zone locks, and the one the last lock used.
struct ZoneProfiles: Codable, Equatable {
    private(set) var all: [ZoneProfile]
    private(set) var currentID: ZoneProfile.ID

    // The first profile made from the old single selection.
    // It has a fixed id, so the app and the extension make the same profile without a write.
    static let firstID = UUID(uuidString: "6F0C1D2E-3A4B-4C5D-8E6F-7A8B9C0D1E2F")!

    init(first: ZoneProfile) {
        all = [first]
        currentID = first.id
    }

    var current: ZoneProfile { profile(currentID) ?? all[0] }
    var canDelete: Bool { all.count > 1 }

    func profile(_ id: ZoneProfile.ID) -> ZoneProfile? {
        all.first { $0.id == id }
    }

    // An unknown id keeps the current profile.
    mutating func choose(_ id: ZoneProfile.ID) {
        guard profile(id) != nil else { return }
        currentID = id
    }

    // Returns nil when the name is blank. Does not change the current profile.
    @discardableResult
    mutating func add(named name: String) -> ZoneProfile.ID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let profile = ZoneProfile(id: UUID(), name: name)
        all.append(profile)
        return profile.id
    }

    // A blank name is ignored.
    mutating func rename(_ id: ZoneProfile.ID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].name = name
    }

    mutating func setSelection(_ selection: FamilyActivitySelection, for id: ZoneProfile.ID) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].selection = selection
    }

    // The last profile is kept. If the current profile goes, the first one left becomes current.
    mutating func delete(_ id: ZoneProfile.ID) {
        guard canDelete else { return }
        all.removeAll { $0.id == id }
        if profile(currentID) == nil { currentID = all[0].id }
    }

    // Reads the saved profiles. Before profiles existed, Zone saved one selection.
    // If there are no saved profiles, that selection becomes the first profile.
    static func load(from defaults: UserDefaults) -> ZoneProfiles {
        if let data = defaults.data(forKey: ZoneLock.Keys.profiles),
           let profiles = try? JSONDecoder().decode(ZoneProfiles.self, from: data),
           !profiles.all.isEmpty {
            return profiles
        }
        let selection = defaults.data(forKey: ZoneLock.Keys.selection)
            .flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) }
            ?? FamilyActivitySelection()
        return ZoneProfiles(first: ZoneProfile(id: firstID, name: "Focus", selection: selection))
    }

    func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: ZoneLock.Keys.profiles)
    }
}
