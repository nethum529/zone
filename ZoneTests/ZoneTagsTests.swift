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

    @Test func existingMainTagIsPreserved() throws {
        try withTags { _, defaults in
            defaults.set("existing", forKey: ZoneLock.Keys.tagID)
            let tags = ZoneTags(defaults: defaults)
            #expect(tags.mainID == "existing")
            #expect(tags.backupID == nil)
            #expect(tags.contains("existing"))
            try tags.setBackup("backup")
            #expect(tags.mainID == "existing")
        }
    }

    @Test func eitherSavedTagIsAcceptedAfterReload() throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            try tags.setBackup("backup")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.mainID == "main")
            #expect(reloaded.backupID == "backup")
            #expect(reloaded.contains("main"))
            #expect(reloaded.contains("backup"))
            #expect(!reloaded.contains("unknown"))
            #expect(!reloaded.contains(""))
        }
    }

    @Test func replacementRevokesOnlyTheOldBackup() throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            try tags.setBackup("old")
            try tags.setBackup("new")
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.contains("main"))
            #expect(reloaded.contains("new"))
            #expect(!reloaded.contains("old"))
        }
    }

    @Test func removalPersistsAndPreservesMainTag() throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            try tags.setBackup("backup")
            try tags.removeBackup()
            let reloaded = ZoneTags(defaults: defaults)
            #expect(reloaded.backupID == nil)
            #expect(!reloaded.contains("backup"))
            #expect(reloaded.contains("main"))
        }
    }

    @Test func tagsMustBeDifferent() throws {
        try withTags { tags, _ in
            try tags.setMain("main")
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.setBackup("main") }
            #expect(tags.backupID == nil)
            try tags.setBackup("backup")
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.setMain("backup") }
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.setBackup("backup") }
            #expect(throws: ZoneTagError.alreadyRegistered) { try tags.setMain("main") }
            #expect(tags.mainID == "main")
            #expect(tags.backupID == "backup")
        }
    }

    @Test func backupNeedsAMainTag() throws {
        try withTags { tags, _ in
            #expect(throws: ZoneTagError.mainTagRequired) { try tags.setBackup("backup") }
            #expect(tags.backupID == nil)
            #expect(throws: ZoneTagError.emptyTag) { try tags.setMain("") }
            #expect(tags.mainID == nil)
        }
    }

    @Test(arguments: [ZoneLock.Keys.zonedSince, ZoneLock.Keys.relockAt])
    func protectedChangesRejectMissingOrUnknownProof(lockKey: String) throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            let lockDate = Date.now
            defaults.set(lockDate, forKey: lockKey)
            #expect(throws: ZoneTagError.verificationRequired) { try tags.setBackup("backup") }
            #expect(throws: ZoneTagError.verificationRequired) { try tags.setMain("new") }
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.setBackup("backup", verifiedBy: "unknown")
            }
            try tags.setBackup("backup", verifiedBy: "main")
            #expect(throws: ZoneTagError.verificationRequired) { try tags.removeBackup() }
            #expect(throws: ZoneTagError.verificationRequired) { try tags.setBackup("new") }
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.removeBackup(verifiedBy: "unknown")
            }
            #expect(tags.mainID == "main")
            #expect(tags.backupID == "backup")
            #expect(defaults.object(forKey: lockKey) as? Date == lockDate)
        }
    }

    @Test(arguments: [ZoneLock.Keys.zonedSince, ZoneLock.Keys.relockAt], ["main", "backup"])
    func eitherTagCanApproveEachProtectedChange(lockKey: String, savedID: String) throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            try tags.setBackup("backup")
            let lockDate = Date.now
            defaults.set(lockDate, forKey: lockKey)
            try tags.setBackup("new-backup", verifiedBy: savedID)
            #expect(tags.backupID == "new-backup")
            #expect(!tags.contains("backup"))
            try tags.setBackup("backup", verifiedBy: "main")
            try tags.setMain("new-main", verifiedBy: savedID)
            #expect(tags.mainID == "new-main")
            #expect(!tags.contains("main"))
            try tags.setMain("main", verifiedBy: "backup")
            try tags.removeBackup(verifiedBy: savedID)
            #expect(tags.backupID == nil)
            #expect(tags.contains("main"))
            #expect(defaults.object(forKey: lockKey) as? Date == lockDate)
        }
    }

    @Test func lockStartingDuringChangeStillNeedsVerification() throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            #expect(!tags.requiresVerification)
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            #expect(throws: ZoneTagError.verificationRequired) { try tags.setBackup("backup") }
            #expect(tags.backupID == nil)
        }
    }

    @Test func replacedTagCannotApproveLaterChanges() throws {
        try withTags { tags, defaults in
            try tags.setMain("main")
            try tags.setBackup("old")
            defaults.set(Date.now, forKey: ZoneLock.Keys.zonedSince)
            try tags.setBackup("new", verifiedBy: "old")
            #expect(throws: ZoneTagError.verificationRequired) {
                try tags.removeBackup(verifiedBy: "old")
            }
            #expect(tags.backupID == "new")
        }
    }
}
