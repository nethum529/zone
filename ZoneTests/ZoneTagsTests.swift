import Foundation
import Testing
@testable import Zone

@MainActor
struct ZoneTagsTests {
    private func withTags(_ body: (ZoneTags, UserDefaults) throws -> Void) rethrows {
        let suite = "ZoneTagsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(ZoneTags(defaults: defaults), defaults)
    }

    @Test func existingMainAndBackupTagsArePreserved() throws {
        try withTags { _, defaults in
            defaults.set("existing", forKey: ZoneLock.Keys.tagID)
            defaults.set("Desk", forKey: "mainTagName")
            defaults.set("backup", forKey: "backupTagID")
            let tags = ZoneTags(defaults: defaults)
            #expect(tags.all == [ZoneTag(id: "existing", name: "Desk"), ZoneTag(id: "backup")])
            #expect(tags.contains("existing"))
            #expect(tags.contains("backup"))
            try tags.add("new")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.all.map(\.id) == ["existing", "backup", "new"])
            #expect(reloaded.tag("existing")?.name == "Desk")
            #expect(defaults.string(forKey: ZoneLock.Keys.tagID) == nil)
        }
    }

    @Test func everySavedTagIsAcceptedAfterReload() throws {
        try withTags { tags, defaults in
            try tags.add("one")
            try tags.add("two")
            try tags.add("three", name: "Keychain")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.contains("one"))
            #expect(reloaded.contains("two"))
            #expect(reloaded.contains("three"))
            #expect(reloaded.tag("three")?.name == "Keychain")
            #expect(!reloaded.contains("unknown"))
            #expect(!reloaded.contains(""))
        }
    }

    @Test func replacementRevokesOnlyTheOldTag() throws {
        try withTags { tags, defaults in
            try tags.add("main")
            try tags.add("old", name: "Desk")
            try tags.replace("old", with: "new")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.contains("main"))
            #expect(reloaded.contains("new"))
            #expect(!reloaded.contains("old"))
            #expect(reloaded.tag("new")?.name == "Desk")
        }
    }

    @Test func deletePersistsAndKeepsTheLastTag() throws {
        try withTags { tags, defaults in
            try tags.add("main")
            try tags.add("backup")
            try tags.delete("main")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(!reloaded.contains("main"))
            #expect(reloaded.contains("backup"))
            #expect(throws: ZoneTagError.lastTag) { try reloaded.delete("backup") }
            #expect(reloaded.contains("backup"))
        }
    }

    @Test func tagsMustBeDifferent() throws {
        try withTags { tags, _ in
            try tags.add("main")
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.add("main") }
            try tags.add("backup")
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.replace("main", with: "backup") }
            #expect(throws: ZoneTagError.emptyTag) { try tags.add("") }
            #expect(tags.all.map(\.id) == ["main", "backup"])
        }
    }

    @Test(arguments: [ZoneLock.Keys.zonedSince, ZoneLock.Keys.relockAt])
    func protectedChangesRejectMissingOrUnknownProof(lockKey: String) throws {
        try withTags { tags, defaults in
            try tags.add("main")
            let lockDate = Date.now
            defaults.set(lockDate, forKey: lockKey)
            #expect(throws: ZoneTagError.verificationRequired) { try tags.add("backup") }
            #expect(throws: ZoneTagError.verificationRequired) { try tags.replace("main", with: "new") }
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.add("backup", verifiedBy: "unknown")
            }
            try tags.add("backup", verifiedBy: "main")
            #expect(throws: ZoneTagError.verificationRequired) { try tags.delete("backup") }
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.delete("backup", verifiedBy: "unknown")
            }
            #expect(tags.all.map(\.id) == ["main", "backup"])
            #expect(defaults.object(forKey: lockKey) as? Date == lockDate)
        }
    }

    @Test(arguments: [ZoneLock.Keys.zonedSince, ZoneLock.Keys.relockAt], ["main", "backup"])
    func anyTagCanApproveEachProtectedChange(lockKey: String, savedID: String) throws {
        try withTags { tags, defaults in
            try tags.add("main")
            try tags.add("backup")
            let lockDate = Date.now
            defaults.set(lockDate, forKey: lockKey)
            try tags.add("third", verifiedBy: savedID)
            try tags.replace("third", with: "new", verifiedBy: savedID)
            #expect(tags.contains("new"))
            #expect(!tags.contains("third"))
            try tags.delete("new", verifiedBy: savedID)
            #expect(!tags.contains("new"))
            #expect(tags.all.map(\.id) == ["main", "backup"])
            #expect(defaults.object(forKey: lockKey) as? Date == lockDate)
        }
    }

    @Test func lockStartingDuringChangeStillNeedsVerification() throws {
        try withTags { tags, defaults in
            try tags.add("main")
            #expect(!tags.requiresVerification)
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            #expect(throws: ZoneTagError.verificationRequired) { try tags.add("backup") }
            #expect(!tags.contains("backup"))
        }
    }

    @Test func replacedTagCannotApproveLaterChanges() throws {
        try withTags { tags, defaults in
            try tags.add("main")
            try tags.add("old")
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            try tags.replace("old", with: "new", verifiedBy: "old")
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.delete("new", verifiedBy: "old")
            }
            #expect(tags.contains("new"))
        }
    }
}
