import SwiftUI

// One half of the Zone mark: two bracket halves that latch into each other.
// The points copy ZoneWidget/Assets.xcassets/zone-mark.imageset/zone-mark.svg (viewBox 476 x 456).
// Give the frame the aspect ratio of ZoneMarkHalf.viewBox. The shape scales to fill it.
struct ZoneMarkHalf: Shape {
    enum Side { case left, right }
    static let viewBox = CGSize(width: 476, height: 456)
    let side: Side

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch side {
        case .left:
            // addLines starts a new subpath at its first point.
            path.addLines([
                CGPoint(x: 45, y: 0), CGPoint(x: 228, y: 0), CGPoint(x: 228, y: 112), CGPoint(x: 112, y: 112),
                CGPoint(x: 112, y: 248), CGPoint(x: 164, y: 248), CGPoint(x: 164, y: 360),
                CGPoint(x: 45, y: 360),
            ])
            path.addArc(tangent1End: CGPoint(x: 0, y: 360), tangent2End: CGPoint(x: 0, y: 0), radius: 45)
            path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: 228, y: 0), radius: 45)
        case .right:
            path.addLines([
                CGPoint(x: 431, y: 456), CGPoint(x: 248, y: 456), CGPoint(x: 248, y: 344),
                CGPoint(x: 364, y: 344), CGPoint(x: 364, y: 208), CGPoint(x: 312, y: 208),
                CGPoint(x: 312, y: 96), CGPoint(x: 431, y: 96),
            ])
            path.addArc(tangent1End: CGPoint(x: 476, y: 96), tangent2End: CGPoint(x: 476, y: 456), radius: 45)
            path.addArc(tangent1End: CGPoint(x: 476, y: 456), tangent2End: CGPoint(x: 248, y: 456), radius: 45)
        }
        path.closeSubpath()
        let scale = CGAffineTransform(scaleX: rect.width / Self.viewBox.width, y: rect.height / Self.viewBox.height)
        return path.applying(scale.concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
