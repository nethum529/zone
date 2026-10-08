import UIKit

// What the Screen Time block screen shows.
// The shield extension and the debug preview in the app both use these values.
// UIKit only: the shield extension has a small memory limit, so it does not load SwiftUI.
enum ShieldLook {
    // The colours of Zone/Theme.swift. Change them together.
    static let ink = color(0xF2F2F0)
    static let mute = color(0x7C7C84)
    static let bone = color(0xECE6DA)
    static let black = color(0x0A0A0C)

    // iOS draws the background colour under a blur, and every blur makes it lighter.
    // Black under this style gave the darkest result, 0x121313, in the iOS 27 simulator.
    // No style gets down to Zone's 0x0A0A0C.
    static let blurStyle = UIBlurEffect.Style.systemChromeMaterialDark
    static let background = color(0x000000)

    static let title = "In the Zone"
    static let button = "Close"

    // "1h 42m in. Scan tag to leave". The second part uses the words of the Home button.
    static func subtitle(zonedSince: Date?, now: Date) -> String {
        let leave = "Scan tag to leave"
        guard let zonedSince else { return leave }
        let time = now.timeIntervalSince(zonedSince)
        guard time >= 60 else { return leave }
        let text = Duration.seconds(time).formatted(
            .units(allowed: [.hours, .minutes], width: .narrow, fractionalPart: .hide(rounded: .down))
        )
        return "\(text) in. \(leave)"
    }

    // The bone Zone mark on a clear background. ShieldIcon.png is a 3x image, so it shows at
    // 72 pt on every device: the mark from the app icon, 156 px wide, centred in 216 px.
    // To use a new logo, run from the repo root (s is any scratch folder):
    // magick Zone/Assets.xcassets/AppIcon.appiconset/AppIcon.png -colorspace gray -level 4%,88% s/mask.png
    // magick -size 1024x1024 xc:'#ECE6DA' s/mask.png -alpha off -compose CopyAlpha -composite PNG32:s/mark.png
    // magick s/mark.png -trim +repage -resize 156x156 -background none -gravity center -extent 216x216 -strip PNG32:ZoneShield/Shield.xcassets/ShieldIcon.imageset/ShieldIcon.png
    // Keep the logo colours. Do not let iOS tint it.
    static let icon = UIImage(named: "ShieldIcon")?.withRenderingMode(.alwaysOriginal)

    private static func color(_ rgb: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
