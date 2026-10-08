import SwiftUI
import Testing
@testable import Zone

struct ZoneMarkTests {
    private let box = CGRect(origin: .zero, size: ZoneMarkHalf.viewBox)

    // The bounds of each subpath in zone-mark.svg.
    @Test func halvesFillTheirPartOfTheViewBox() {
        let left = ZoneMarkHalf(side: .left).path(in: box).boundingRect
        let right = ZoneMarkHalf(side: .right).path(in: box).boundingRect
        #expect(left.isClose(to: CGRect(x: 0, y: 0, width: 228, height: 360)))
        #expect(right.isClose(to: CGRect(x: 248, y: 96, width: 228, height: 360)))
    }

    @Test func outerCornersAreRoundAndNotchesAreEmpty() {
        let left = ZoneMarkHalf(side: .left).path(in: box)
        #expect(!left.contains(CGPoint(x: 4, y: 4)))
        #expect(!left.contains(CGPoint(x: 4, y: 356)))
        #expect(left.contains(CGPoint(x: 20, y: 20)))
        #expect(!left.contains(CGPoint(x: 140, y: 180)))
        let right = ZoneMarkHalf(side: .right).path(in: box)
        #expect(!right.contains(CGPoint(x: 472, y: 100)))
        #expect(!right.contains(CGPoint(x: 472, y: 452)))
        #expect(!right.contains(CGPoint(x: 336, y: 276)))
    }

    @Test func scalesToItsFrame() {
        let rect = CGRect(x: 10, y: 20, width: 119, height: 114)
        let left = ZoneMarkHalf(side: .left).path(in: rect).boundingRect
        #expect(left.isClose(to: CGRect(x: 10, y: 20, width: 57, height: 90)))
    }
}

private extension CGRect {
    func isClose(to other: CGRect) -> Bool {
        abs(minX - other.minX) < 0.01 && abs(minY - other.minY) < 0.01
            && abs(width - other.width) < 0.01 && abs(height - other.height) < 0.01
    }
}
