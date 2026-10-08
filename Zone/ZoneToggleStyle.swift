import SwiftUI

// A switch that is a word: On in bone, Off in grey, where a row shows its value.
// On a change the words roll: On lives below, Off lives above.
struct ZoneToggleStyle: ToggleStyle {
    // The word is the same size as the label beside it.
    var size: CGFloat = 17
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        // The words move 70 percent of their height.
        let travel = reduceMotion ? 0 : size * 0.85
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                    .foregroundStyle(Color.zoneMute)
                Spacer()
                ZStack(alignment: .trailing) {
                    Text("Off")
                        .foregroundStyle(Color.zoneMute)
                        .offset(y: isOn ? -travel : 0)
                        .opacity(isOn ? 0 : 1)
                    Text("On")
                        .foregroundStyle(Color.zoneBone)
                        .offset(y: isOn ? 0 : travel)
                        .opacity(isOn ? 1 : 0)
                }
                .font(.system(size: size, weight: .semibold))
                .frame(width: 48, height: 30, alignment: .trailing)
                .clipped()
                .animation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.22), value: isOn)
                .accessibilityHidden(true)
            }
            .font(.system(size: 17))
            .frame(height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(ZoneRowStyle())
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
