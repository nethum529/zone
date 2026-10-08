import SwiftUI

// A bone switch: a dark knob on bone when on, a grey knob on the track when off.
struct ZoneToggleStyle: ToggleStyle {
    var showsLabel = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                if showsLabel {
                    configuration.label
                        .foregroundStyle(Color.zoneMute)
                    Spacer()
                }
                Capsule()
                    .fill(configuration.isOn ? Color.zoneBone : Color.zoneTrack)
                    .frame(width: 50, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Color.zoneBackground : Color.zoneMute)
                            .padding(4)
                    }
                    .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: configuration.isOn)
            }
            .font(.system(size: 17))
            .frame(height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(ZoneRowStyle())
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}
