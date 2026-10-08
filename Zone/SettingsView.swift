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
                        ZoneRow("Profiles", value: store.profiles.current.name)
                    }
                    Button { showingTags = true } label: {
                        ZoneRow("Zone tags", value: tagSummary)
                    }
                    Button { showingSchedules = true } label: {
                        ZoneRow("Schedules", value: scheduleText)
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
                            ZoneRow("Relock after", value: "\(store.relockMinutes) min") {
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
                        ZoneRow("Emergency unlock", value: "\(remaining)")
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
}

// A settings row: dim when pressed, and faded like ZoneButtonStyle when disabled.
struct ZoneRowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}
