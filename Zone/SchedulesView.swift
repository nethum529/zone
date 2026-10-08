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
                    Text("Enter and leave the Zone at set times.")
                        .foregroundStyle(Color.zoneMute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    Spacer()
                } else {
                    // A plain list keeps the native swipe action without grouped cards.
                    List {
                        ForEach(store.schedules) { schedule in
                            Button { editor = schedule } label: {
                                scheduleRow(schedule)
                            }
                            .buttonStyle(ZoneRowStyle())
                            .accessibilityLabel("Edit \(schedule.displayName), \(schedule.daysText), \(schedule.timeText)")
                            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.zoneBackground)
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
                        if let setupMessage {
                            Text(setupMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.zoneMute)
                                .listRowInsets(EdgeInsets(top: 16, leading: 24, bottom: 0, trailing: 24))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.zoneBackground)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add schedule") { editor = ZoneSchedule(profileID: zone.profiles.currentID) }
                    .buttonStyle(ZoneButtonStyle())
                    .padding(24)
                    .background(Color.zoneBackground)
            }
            .schedulePage()
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
            VStack(alignment: .leading, spacing: 8) {
                Text(schedule.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.zoneInk)
                Text("\(schedule.daysText) · \(schedule.timeText)")
                    .font(.subheadline)
                    .foregroundStyle(Color.zoneMute)
            }
            Spacer(minLength: 0)
            if store.runningID == schedule.id {
                Text("In the Zone").font(.subheadline).foregroundStyle(Color.zoneMute)
            } else if !schedule.isEnabled {
                Text("Off").font(.subheadline).foregroundStyle(Color.zoneMute)
            }
            ZoneCaret().padding(.trailing, -4)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(.rect)
    }
}
