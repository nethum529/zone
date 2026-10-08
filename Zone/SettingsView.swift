import SwiftUI

struct SettingsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var showingTags = false
    @State private var showingProfiles = false
    @State private var showingSchedules = false

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            ZoneTitle("Settings")
            ScrollView {
                VStack(spacing: 0) {
                    Button { showingTags = true } label: {
                        row("Zone tags", value: tagSummary)
                    }
                    Button { showingProfiles = true } label: {
                        row("Profiles", value: store.profiles.current.name)
                    }
                    Button { showingSchedules = true } label: {
                        row("Schedules", value: scheduleText)
                    }
                    VStack(spacing: 0) {
                        Toggle(isOn: $store.superZone) {
                            Text("Super Zone")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.zoneInk)
                        }
                        .toggleStyle(ZoneToggleStyle())
                        .frame(height: 64)
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
                    EmergencyUnlockSettingsRow { remaining in
                        row("Emergency unlock", value: "\(remaining)")
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
        .sheet(isPresented: $showingTags) { ZoneTagsView(tags: store.tags) }
        .sheet(isPresented: $showingSchedules) { SchedulesView() }
    }

    // One list, one row: label and value in ink at one size, no gaps or lines.
    private func row<Trailing: View>(_ label: String, value: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .fontWeight(.medium)
                .layoutPriority(1)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
                .monospacedDigit()
            trailing()
                // The caret ink ends 4 pt inside its frame. Line it up with the switch edge.
                .padding(.trailing, -4)
        }
        .font(.system(size: 20))
        .foregroundStyle(Color.zoneInk)
        .frame(height: 64)
        .contentShape(.rect)
    }

    private func row(_ label: String, value: String) -> some View {
        row(label, value: value) { ZoneCaret() }
    }

    private var tagSummary: String {
        if store.tags.backupID != nil { "2" }
        else if store.tags.mainID != nil { "1" }
        else { "Register" }
    }

    private var scheduleText: String {
        let count = store.scheduleStore.schedules.count
        return count == 0 ? "None" : "\(count)"
    }
}

// A settings row: dim when pressed, and faded like ZoneButtonStyle when disabled.
struct ZoneRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}
