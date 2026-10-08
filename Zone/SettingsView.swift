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
                    Button { showingProfiles = true } label: {
                        row("Profiles", value: store.profiles.current.name) { ZoneCaret() }
                    }
                    Button { showingTags = true } label: {
                        row("Zone tags", value: tagSummary) { ZoneCaret() }
                    }
                    Button { showingSchedules = true } label: {
                        row("Schedules", value: scheduleText) { ZoneCaret() }
                    }
                    .padding(.top, 24)
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
        .sheet(isPresented: $showingTags) { ZoneTagsView(tags: store.tags) }
        .sheet(isPresented: $showingSchedules) { SchedulesView() }
    }

    private var tagSummary: String {
        if store.tags.backupID != nil { "2 tags" }
        else if store.tags.mainID != nil { "1 tag" }
        else { "Register" }
    }

    private var scheduleText: String {
        let count = store.scheduleStore.schedules.count
        return count == 0 ? "None" : "\(count) schedule\(count == 1 ? "" : "s")"
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
struct ZoneRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}
