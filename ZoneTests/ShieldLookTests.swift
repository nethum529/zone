import Foundation
import Testing
@testable import Zone

struct ShieldLookTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func subtitleShowsTimeAndHowToLeave() {
        let since = now.addingTimeInterval(-(102 * 60 + 8))
        #expect(ShieldLook.subtitle(zonedSince: since, now: now) == "1h 42m in. Scan tag to leave")
    }

    @Test func subtitleRoundsDown() {
        let since = now.addingTimeInterval(-(45 * 60 + 59))
        #expect(ShieldLook.subtitle(zonedSince: since, now: now) == "45m in. Scan tag to leave")
    }

    @Test func subtitleUnderOneMinuteOnlySaysHowToLeave() {
        #expect(ShieldLook.subtitle(zonedSince: now.addingTimeInterval(-59), now: now) == "Scan tag to leave")
        #expect(ShieldLook.subtitle(zonedSince: now.addingTimeInterval(30), now: now) == "Scan tag to leave")
    }

    @Test func subtitleWithoutStartTimeOnlySaysHowToLeave() {
        #expect(ShieldLook.subtitle(zonedSince: nil, now: now) == "Scan tag to leave")
    }

    @Test func iconLoadsAtFixedSize() throws {
        let icon = try #require(ShieldLook.icon)
        #expect(icon.size == CGSize(width: 72, height: 72))
        #expect(icon.scale == 3)
    }
}
