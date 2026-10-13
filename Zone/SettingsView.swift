import SwiftUI

struct SettingsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var showingTags = false
    @State private var showingProfiles = false
    @State private var showingSchedules = false
    @State private var showingSuperZone = false
    #if DEBUG
    @State private var confirmingReplay = false
    @State private var replayError: String?
    #endif

    var body: some View {
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
                    Button { showingSuperZone = true } label: {
                        row("Super Zone", value: store.superZone ? "\(store.relockMinutes) min" : "Off")
                    }
                    EmergencyUnlockSettingsRow { remaining in
                        row("Emergency unlock", value: "\(remaining)")
                    }
                    #if DEBUG
                    Button { confirmingReplay = true } label: {
                        row("Replay setup", value: "")
                    }
                    .disabled(store.isZoned || store.isRequestingAuthorization)
                    if store.isZoned {
                        Text("Leave the Zone to replay setup.")
                            .font(.zone(size: 15))
                            .foregroundStyle(Color.zoneMute)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                    }
                    #endif
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
        .sheet(isPresented: $showingSuperZone) { SuperZoneView() }
        #if DEBUG
        .confirmationDialog("Replay setup?", isPresented: $confirmingReplay, titleVisibility: .visible) {
            Button("Replay setup") {
                Task {
                    do { try await store.replaySetup() }
                    catch { replayError = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keep your data and apps. Allow Screen Time again.")
        }
        .alert("Could not replay setup", isPresented: Binding(
            get: { replayError != nil }, set: { if !$0 { replayError = nil } }
        )) {
            Button("OK", role: .cancel) { replayError = nil }
        } message: {
            Text(replayError ?? "")
        }
        #endif
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
        .font(.zone(size: 20))
        .foregroundStyle(Color.zoneInk)
        .frame(height: 64)
        .contentShape(.rect)
    }

    private func row(_ label: String, value: String) -> some View {
        row(label, value: value) { ZoneCaret() }
    }

    private var tagSummary: String {
        store.tags.all.isEmpty ? "Register" : "\(store.tags.all.count)"
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
