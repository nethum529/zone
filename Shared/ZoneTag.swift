import Foundation

// One saved NFC tag. The id is the tag chip ID. Any saved tag can leave the Zone.
struct ZoneTag: Codable, Identifiable, Equatable {
    let id: String
    // A name the user gives the tag, like Desk or Keychain.
    var name: String?

    // Before the tag list, Zone kept one main tag (ZoneLock.Keys.tagID) and one backup tag.
    private static let oldBackupKey = "backupTagID"
    private static let oldMainNameKey = "mainTagName"
    private static let oldBackupNameKey = "backupTagName"

    // Reads the saved tags. If there is no list yet, the old main and backup tags become the list.
    // This does not write, so the app and the extensions read the same tags before the first save.
    static func load(from defaults: UserDefaults) -> [ZoneTag] {
        if let data = defaults.data(forKey: ZoneLock.Keys.tags),
           let tags = try? JSONDecoder().decode([ZoneTag].self, from: data) {
            return tags
        }
        var tags: [ZoneTag] = []
        if let id = defaults.string(forKey: ZoneLock.Keys.tagID) {
            tags.append(ZoneTag(id: id, name: defaults.string(forKey: oldMainNameKey)))
        }
        if let id = defaults.string(forKey: oldBackupKey), !tags.contains(where: { $0.id == id }) {
            tags.append(ZoneTag(id: id, name: defaults.string(forKey: oldBackupNameKey)))
        }
        return tags
    }

    // Writes the list, then removes the old keys, because the list now holds those tags.
    static func save(_ tags: [ZoneTag], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        defaults.set(data, forKey: ZoneLock.Keys.tags)
        for key in [ZoneLock.Keys.tagID, oldBackupKey, oldMainNameKey, oldBackupNameKey] {
            defaults.removeObject(forKey: key)
        }
    }
}
