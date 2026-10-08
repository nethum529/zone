import Foundation
import Testing
@testable import Zone

struct ShieldLookTests {
    @Test func subtitleOnlySaysHowToLeave() {
        #expect(ShieldLook.subtitle == "Scan tag to leave")
    }

    @Test func iconLoadsAtFixedSize() throws {
        let icon = try #require(ShieldLook.icon)
        #expect(icon.size == CGSize(width: 72, height: 72))
        #expect(icon.scale == 3)
    }
}
