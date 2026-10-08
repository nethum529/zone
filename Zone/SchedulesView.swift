import SwiftUI

struct SchedulesView: View {
    @Environment(ZoneStore.self) private var zone
    @Environment(\.dismiss) private var dismiss
    @State private var editor: ZoneSchedule?
    @State private var errorMessage: String?

    private var store: ZoneScheduleStore { zone.scheduleStore }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Schedules")
                if store.schedules.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Enter and leave the Zone at set times.")
                            .font(.body)
                            .foregroundStyle(Color.zoneMute)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                } else {
                    List {
                        Section {
                            ForEach(store.schedules) { schedule in
                                scheduleRow(schedule)
                                    .listRowBackground(Color.zoneCard)
                                    .swipeActions {
                                        if store.runningID != schedule.id {
                                            Button("Delete", role: .destructive) {
                                                do { try store.delete(schedule.id) }
                                                catch { errorMessage = error.localizedDescription }
                                            }
                                            .tint(.red)
                                        }
                                    }
                            }
                        } footer: {
                            if let setupMessage { Text(setupMessage) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add schedule") { editor = ZoneSchedule(profileID: zone.profiles.currentID) }
                    .buttonStyle(ZoneButtonStyle())
                    .padding(24)
            }
            .background(Color.zoneBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editor) { schedule in
                ScheduleEditorView(schedule: schedule, isNew: !store.schedules.contains { $0.id == schedule.id })
            }
            .alert("Could not update schedule", isPresented: .init(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.zoneInk)
        .tint(Color.zoneBone)
        .preferredColorScheme(.dark)
    }

    private var setupMessage: String? {
        let enabled = store.schedules.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }
        if zone.registeredTagID == nil { return "Register your tag on Home to use schedules." }
        let profiles = enabled.compactMap { $0.profile(in: zone.profiles) }
        if profiles.count != enabled.count { return "Choose a profile for each schedule." }
        if profiles.contains(where: {
            $0.selection.applicationTokens.isEmpty && $0.selection.categoryTokens.isEmpty
                && $0.selection.webDomainTokens.isEmpty
        }) { return "Choose blocked apps in Profiles to use schedules." }
        return nil
    }

    private func scheduleRow(_ schedule: ZoneSchedule) -> some View {
        HStack(spacing: 16) {
            Button { editor = schedule } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(schedule.timeText)
                        .font(.body)
                        .foregroundStyle(Color.zoneInk)
                    Text(schedule.daysText + (store.runningID == schedule.id ? " · In the Zone" : ""))
                        .font(.subheadline)
                        .foregroundStyle(Color.zoneMute)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit schedule, \(schedule.daysText), \(schedule.timeText)")
            Toggle("Enabled", isOn: Binding(
                get: { schedule.isEnabled },
                set: { enabled in
                    var updated = schedule
                    updated.isEnabled = enabled
                    do { try store.save(updated) }
                    catch { errorMessage = error.localizedDescription }
                }
            ))
            .labelsHidden()
            .toggleStyle(ZoneToggleStyle(showsLabel: false))
            .disabled(store.runningID == schedule.id)
            .accessibilityLabel("\(schedule.daysText), \(schedule.timeText)")
        }
    }
}
