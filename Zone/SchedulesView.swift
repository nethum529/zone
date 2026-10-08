import SwiftUI

struct SchedulesView: View {
    @Environment(ZoneStore.self) private var zone
    @Environment(\.dismiss) private var dismiss
    @State private var editor: ZoneSchedule?
    @State private var errorMessage: String?
    // The row that shows Delete now.
    @State private var swiped: UUID?
    // Deleted by swipe but still kept until the undo line hides.
    @State private var pending: ZoneSchedule?

    private var store: ZoneScheduleStore { zone.scheduleStore }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Schedules")
                if visible.isEmpty {
                    Text("Enter and leave the Zone at set times.")
                        .foregroundStyle(Color.zoneMute)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(visible) { schedule in
                                Button { editor = schedule } label: {
                                    scheduleRow(schedule)
                                }
                                .buttonStyle(ZoneRowStyle())
                                .accessibilityLabel("Edit \(schedule.displayName), \(schedule.daysText), \(schedule.timeText)")
                                .padding(.horizontal, 24)
                                // A running schedule cannot be deleted.
                                .swipeToDelete(schedule.id, open: $swiped, enabled: store.runningID != schedule.id) {
                                    swipeDelete(schedule)
                                }
                            }
                            if let setupMessage {
                                Text(setupMessage)
                                    .font(.footnote)
                                    .foregroundStyle(Color.zoneMute)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 24)
                                    .padding(.top, 16)
                            }
                        }
                    }
                    .padding(.top, 24)
                    .onScrollPhaseChange { _, phase in
                        if phase != .idle { swiped = nil }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add schedule") {
                    if let pending { commit(pending) }
                    editor = ZoneSchedule(profileID: zone.profiles.currentID)
                }
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .undoLine($pending, text: { "\($0.displayName) deleted" }, commit: commit)
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

    // The schedules on screen. One that waits for its undo line is already gone.
    private var visible: [ZoneSchedule] {
        store.schedules.filter { $0.id != pending?.id }
    }

    private func swipeDelete(_ schedule: ZoneSchedule) {
        if let pending { commit(pending) }
        withAnimation(.smooth(duration: 0.34)) {
            swiped = nil
            pending = schedule
        }
    }

    // The undo line hid, so the delete is final. If the schedule started meanwhile, it comes back.
    private func commit(_ schedule: ZoneSchedule) {
        do { try store.delete(schedule.id) }
        catch { errorMessage = error.localizedDescription }
        withAnimation(.smooth(duration: 0.34)) { pending = nil }
    }

    private var setupMessage: String? {
        let enabled = visible.filter(\.isEnabled)
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
            .swipeLabel()
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                if store.runningID == schedule.id {
                    Text("In the Zone").font(.subheadline).foregroundStyle(Color.zoneMute)
                } else if !schedule.isEnabled {
                    Text("Off").font(.subheadline).foregroundStyle(Color.zoneMute)
                }
                ZoneCaret().padding(.trailing, -4)
            }
            .swipeValue()
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(.rect)
    }
}
