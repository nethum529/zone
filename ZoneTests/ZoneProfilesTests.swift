import FamilyControls
import Foundation
import Testing
@testable import Zone

struct ZoneProfilesTests {
    // A fresh store for each test, never the App Group.
    let defaults = UserDefaults(suiteName: "ZoneProfilesTests-\(UUID())")!

    @Test func oldSelectionBecomesTheFirstProfile() throws {
        let old = FamilyActivitySelection(includeEntireCategory: true)
        try #require(old != FamilyActivitySelection())
        defaults.set(try JSONEncoder().encode(old), forKey: ZoneLock.Keys.selection)
        let profiles = ZoneProfiles.load(from: defaults)
        #expect(profiles.all.count == 1)
        #expect(profiles.current.name == "Focus")
        #expect(profiles.current.selection == old)
    }

    @Test func firstProfileHasTheSameIDOnEveryLoad() {
        let first = ZoneProfiles.load(from: defaults)
        let second = ZoneProfiles.load(from: defaults)
        #expect(first.currentID == second.currentID)
    }

    @Test func chosenProfileIsSavedForTheRelock() throws {
        var profiles = ZoneProfiles.load(from: defaults)
        let addedSleep = profiles.add(named: "Sleep")
        let sleep = try #require(addedSleep)
        profiles.choose(sleep)
        profiles.save(to: defaults)
        #expect(ZoneProfiles.load(from: defaults).current.id == sleep)
    }

    @Test func deletingTheCurrentProfileChoosesTheFirstLeft() throws {
        var profiles = ZoneProfiles.load(from: defaults)
        let first = profiles.currentID
        let addedWork = profiles.add(named: "Work")
        let work = try #require(addedWork)
        profiles.choose(work)
        profiles.delete(work)
        #expect(profiles.currentID == first)
        #expect(profiles.profile(work) == nil)
    }

    @Test func lastProfileCannotBeDeleted() {
        var profiles = ZoneProfiles.load(from: defaults)
        profiles.delete(profiles.currentID)
        #expect(profiles.all.count == 1)
        #expect(!profiles.canDelete)
    }

    @Test func namesAreTrimmedAndBlankNamesIgnored() throws {
        var profiles = ZoneProfiles.load(from: defaults)
        let blank = profiles.add(named: "   ")
        #expect(blank == nil)
        let addedWork = profiles.add(named: "  Work ")
        let work = try #require(addedWork)
        #expect(profiles.profile(work)?.name == "Work")
        profiles.rename(work, to: " ")
        #expect(profiles.profile(work)?.name == "Work")
        profiles.rename(work, to: " Deep work ")
        #expect(profiles.profile(work)?.name == "Deep work")
    }

    @Test func unknownProfileIsNotChosen() {
        var profiles = ZoneProfiles.load(from: defaults)
        let current = profiles.currentID
        profiles.choose(UUID())
        #expect(profiles.currentID == current)
    }

    @Test func addingDoesNotChangeTheCurrentProfile() {
        var profiles = ZoneProfiles.load(from: defaults)
        let current = profiles.currentID
        profiles.add(named: "Work")
        #expect(profiles.currentID == current)
    }

    @Test func lockSelectionComesFromTheCurrentProfile() throws {
        var profiles = ZoneProfiles.load(from: defaults)
        let addedSleep = profiles.add(named: "Sleep")
        let sleep = try #require(addedSleep)
        let apps = FamilyActivitySelection(includeEntireCategory: true)
        profiles.setSelection(apps, for: sleep)
        profiles.choose(sleep)
        #expect(profiles.current.selection == apps)
        #expect(profiles.profile(profiles.all[0].id)?.selection == FamilyActivitySelection())
    }
}
