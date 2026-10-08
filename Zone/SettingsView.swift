import SwiftUI

struct SettingsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var scanner = TagScanner()
    @State private var showingProfiles = false

    var body: some View {
        @Bindable var store = store
        // Only when unlocked, so a new tag or fewer blocked apps cannot be used to leave the Zone.
        let locked = store.isZoned || store.relockAt != nil
        VStack(spacing: 0) {
            ZoneTitle("Settings")
            ScrollView {
                VStack(spacing: 0) {
                    Button { showingProfiles = true } label: {
                        row("Profiles", value: store.profiles.current.name) { ZoneCaret() }
                    }
                    Button {
                        Task {
                            if let id = await scanner.scan() { store.registerTag(id) }
                        }
                    } label: {
                        row("Zone tag", value: store.registeredTagID == nil ? "Register" : "Change") { ZoneCaret() }
                    }
                    .disabled(locked)
                    VStack(spacing: 0) {
                        Toggle("Super Zone", isOn: $store.superZone)
                            .toggleStyle(ZoneToggleStyle())
                        Menu {
                            Picker("Relock after", selection: $store.relockMinutes) {
                                ForEach(ZoneStore.relockChoices, id: \.self) { Text("\($0) min") }
                            }
                        } label: {
                            row("Relock after", value: "\(store.relockMinutes) min") {
                                Image("caret-up-down")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                    .foregroundStyle(Color.zoneMute)
                            }
                        }
                    }
                    .disabled(store.relockAt != nil)
                    .padding(.top, 24)
                    EmergencyUnlockSettingsRow { remaining in
                        row("Emergency unlock", value: "\(remaining)") { ZoneCaret() }
                    }
                }
                .buttonStyle(ZoneRowStyle())
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
        .sheet(isPresented: $showingProfiles) { ProfilesView() }
        .tagScanAlert(scanner)
    }

    // The same label and value row as on Home.
    private func row(_ label: String, value: String, @ViewBuilder caret: () -> some View) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(Color.zoneMute)
                .layoutPriority(1)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
                .monospacedDigit()
            caret()
                // The caret ink ends 4 pt inside its frame. Line it up with the switch edge.
                .padding(.trailing, -4)
        }
        .font(.system(size: 17))
        .frame(height: 52)
        .contentShape(.rect)
    }
}

// A settings row: dim when pressed, and faded like ZoneButtonStyle when disabled.
private struct ZoneRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

// A bone switch: a dark knob on bone when on, a grey knob on the track when off.
private struct ZoneToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                    .foregroundStyle(Color.zoneMute)
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? Color.zoneBone : Color.zoneTrack)
                    .frame(width: 50, height: 30)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(configuration.isOn ? Color.zoneBackground : Color.zoneMute)
                            .padding(4)
                    }
                    .animation(.smooth(duration: 0.2), value: configuration.isOn)
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
