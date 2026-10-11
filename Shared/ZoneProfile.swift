import FamilyControls
import Foundation

// A named set of blocked apps and websites, for example Work or Sleep.
// The id never changes, so other features (such as schedules) can point to a profile.
struct ZoneProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var selection = FamilyActivitySelection()
    // Sites typed by address, for example instagram.com. The web filter blocks them in Safari and other browsers.
    var sites: [String] = []

    var blocksSomething: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty || !sites.isEmpty
    }

    // The web filter takes at most 50 sites.
    static let maxSites = 50

    // "https://www.Instagram.com/explore" becomes "instagram.com". Returns nil when the text is not a site.
    static func site(from text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let url = URL(string: text.contains("://") ? text : "https://" + text)
        guard var host = url?.host(), host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }
}

extension ZoneProfile {
    // Profiles saved before sites existed have no sites key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        selection = try container.decode(FamilyActivitySelection.self, forKey: .selection)
        sites = try container.decodeIfPresent([String].self, forKey: .sites) ?? []
    }
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

    // Returns false when the text is not a site or the list is full. A site already in the list is not added again.
    @discardableResult
    mutating func addSite(_ text: String, to id: ZoneProfile.ID) -> Bool {
        guard let site = ZoneProfile.site(from: text),
              let index = all.firstIndex(where: { $0.id == id }),
              all[index].sites.count < ZoneProfile.maxSites
        else { return false }
        if !all[index].sites.contains(site) { all[index].sites.append(site) }
        return true
    }

    mutating func removeSite(_ site: String, from id: ZoneProfile.ID) {
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].sites.removeAll { $0 == site }
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
