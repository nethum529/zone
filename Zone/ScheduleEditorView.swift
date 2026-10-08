import SwiftUI

struct ScheduleEditorView: View {
    @Environment(ZoneStore.self) private var zone
    @Environment(\.dismiss) private var dismiss
    @State var schedule: ZoneSchedule
    let isNew: Bool
    @State private var errorMessage: String?
    @State private var field: Field?
    @FocusState private var editingName: Bool

    private enum Field: String, Identifiable {
        case profile, repeatDays, start, end
        var id: Self { self }
    }

    private var isRunning: Bool { zone.scheduleStore.runningID == schedule.id }
    private var validationMessage: String? {
        if schedule.profile(in: zone.profiles) == nil { return "Choose a profile." }
        return schedule.validationMessage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle(isNew ? "New schedule" : "Edit schedule")
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Text("Name").foregroundStyle(Color.zoneMute)
                            TextField("Schedule", text: Binding(
                                get: { schedule.name ?? "" }, set: { schedule.name = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.trailing)
                            .focused($editingName)
                            .submitLabel(.done)
                            .onSubmit { editingName = false }
                            .accessibilityLabel("Schedule name")
                            .accessibilityIdentifier("schedule-name")
                        }
                        .frame(minHeight: 52)
                        .contentShape(.rect)
                        .onTapGesture { editingName = true }
                        .disabled(isRunning)
                        .opacity(isRunning ? 0.4 : 1)

                        editRow("Profile", value: schedule.profile(in: zone.profiles)?.name ?? "Choose", field: .profile)
                        editRow("Repeat", value: schedule.weekdays.isEmpty ? "Choose days" : schedule.daysText, field: .repeatDays)
                            .padding(.top, 24)
                        editRow("Start", value: ZoneSchedule.time(schedule.startMinute).formatted(date: .omitted, time: .shortened), field: .start)
                        editRow(schedule.crossesMidnight ? "End next day" : "End",
                                value: ZoneSchedule.time(schedule.endMinute).formatted(date: .omitted, time: .shortened), field: .end)
                        Toggle(isOn: $schedule.isEnabled) {
                            Text("Enabled").font(.body)
                        }
                        .toggleStyle(ZoneToggleStyle())
                        .disabled(isRunning)
                        .padding(.top, 24)

                        if isRunning {
                            note("Scan your tag on Home to edit this running schedule.")
                        } else if let message = validationMessage {
                            note(message)
                        }
                        if !isRunning && !isNew {
                            Button(role: .destructive) {
                                do {
                                    try zone.scheduleStore.delete(schedule.id)
                                    dismiss()
                                } catch { errorMessage = error.localizedDescription }
                            } label: {
                                Text("Delete schedule")
                                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                    .contentShape(.rect)
                            }
                            .foregroundStyle(.red)
                            .padding(.top, 24)
                        }
                    }
                    .font(.body)
                    .buttonStyle(ZoneRowStyle())
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                if !isRunning {
                    Button("Save schedule") {
                        do {
                            try zone.scheduleStore.save(schedule)
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }
                    .buttonStyle(ZoneButtonStyle())
                    .disabled(validationMessage != nil)
                    .padding(24)
                    .background(Color.zoneBackground)
                }
            }
            .schedulePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isRunning ? "Done" : "Cancel") { dismiss() }
                }
            }
            .sheet(item: $field) { field in
                switch field {
                case .profile:
                    ScheduleProfileSheet(profileID: $schedule.profileID)
                case .repeatDays:
                    ScheduleDaysSheet(weekdays: $schedule.weekdays)
                case .start:
                    ScheduleTimeSheet(title: "Start time", minute: $schedule.startMinute)
                case .end:
                    ScheduleTimeSheet(title: "End time", minute: $schedule.endMinute)
                }
            }
            .alert("Could not save schedule", isPresented: .init(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func editRow(_ title: String, value: String, field: Field) -> some View {
        Button {
            editingName = false
            self.field = field
        } label: {
            ScheduleValueRow(title: title, value: value)
        }
        .disabled(isRunning)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Color.zoneMute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
    }
}
