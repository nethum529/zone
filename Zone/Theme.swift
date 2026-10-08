import SwiftUI

// The colours of the bone design: warm white on black.
// ZoneShield/ShieldLook.swift has a copy of these values. Change them together.
extension Color {
    static let zoneBackground = Color(rgb: 0x0A0A0C)
    static let zoneCard = Color(rgb: 0x141418)
    static let zoneInk = Color(rgb: 0xF2F2F0)
    static let zoneMute = Color(rgb: 0x7C7C84)
    static let zoneTrack = Color(rgb: 0x1C1C22)
    static let zoneBone = Color(rgb: 0xECE6DA)

    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// "2h 15m", "5m" or "0m".
func zoneTimeText(_ time: TimeInterval) -> String {
    Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
}

// The large page title at the top of each tab.
struct ZoneTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 34, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
    }
}

// The one main button style: a bone capsule with dark text.
struct ZoneButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.zoneBackground)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.zoneBone, in: .capsule)
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.smooth(duration: 0.2), value: configuration.isPressed)
    }
}

// A Settings row label: an icon tile and a title.
struct ZoneRowLabel: View {
    let icon: String
    let title: String

    init(_ icon: String, _ title: String) {
        self.icon = icon
        self.title = title
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.zoneBone)
                .frame(width: 30, height: 30)
                .background(Color.zoneBone.opacity(0.14), in: .rect(cornerRadius: 9))
            Text(title)
                .foregroundStyle(Color.zoneInk)
        }
    }
}

// A Settings row that opens something: label, value and caret.
struct ZoneRow: View {
    let icon: String
    let title: String
    let value: String

    init(_ icon: String, _ title: String, value: String) {
        self.icon = icon
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            ZoneRowLabel(icon, title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.zoneMute)
                .lineLimit(1)
            ZoneCaret()
        }
    }
}

// The caret at the end of a row that opens something.
struct ZoneCaret: View {
    var body: some View {
        Image("caret-right")
            .resizable()
            .frame(width: 14, height: 14)
            .foregroundStyle(Color.zoneMute)
    }
}
