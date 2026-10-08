import SwiftUI

struct ScheduleEditorView: View {
    @Environment(ZoneStore.self) private var zone
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State var schedule: ZoneSchedule
    let isNew: Bool
    @State private var errorMessage: String?

    private var isRunning: Bool { zone.scheduleStore.runningID == schedule.id }
    private var validationMessage: String? {
        if schedule.profile(in: zone.profiles) == nil { return "Choose a profile." }
        return schedule.validationMessage
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Profile", selection: Binding(
                        get: { schedule.profile(in: zone.profiles)?.id },
                        set: { schedule.profileID = $0 }
                    )) {
                        if schedule.profile(in: zone.profiles) == nil {
                            Text("Choose a profile").tag(nil as ZoneProfile.ID?)
                                .disabled(true)
                        }
                        ForEach(zone.profiles.all) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.zoneMute)
                    .disabled(isRunning)
                }
                .listRowBackground(Color.zoneCard)
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Repeat")
                        if typeSize.isAccessibilitySize {
                            ForEach(ZoneSchedule.orderedWeekdays, id: \.self) { day in
                                dayButton(day, expanded: true)
                            }
                        } else {
                            HStack(spacing: 2) {
                                ForEach(ZoneSchedule.orderedWeekdays, id: \.self) { day in
                                    dayButton(day, expanded: false)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } footer: {
                    if schedule.weekdays.isEmpty { Text("Choose at least one day.") }
                }
                .listRowBackground(Color.zoneCard)
                Section {
                    timePicker("Start", minute: $schedule.startMinute)
                    timePicker(schedule.crossesMidnight ? "End next day" : "End", minute: $schedule.endMinute)
                } footer: {
                    if isRunning {
                        Text("Scan your tag on Home to edit this running schedule.")
                    } else if let message = validationMessage, !schedule.weekdays.isEmpty {
                        Text(message)
                    } else {
                        Text("Zone ends on time. Scan your tag to leave early.")
                    }
                }
                .listRowBackground(Color.zoneCard)
                if !isRunning && !isNew {
                    Section {
                        Button("Delete schedule", role: .destructive) {
                            do {
                                try zone.scheduleStore.delete(schedule.id)
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                    }
                    .listRowBackground(Color.zoneCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.zoneBackground)
            .navigationTitle(isNew ? "New schedule" : "Edit schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: isRunning ? .confirmationAction : .cancellationAction) {
                    Button(isRunning ? "Done" : "Cancel") { dismiss() }
                }
                if !isRunning {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            do {
                                try zone.scheduleStore.save(schedule)
                                dismiss()
                            } catch { errorMessage = error.localizedDescription }
                        }
                        .fontWeight(.semibold)
                        .disabled(validationMessage != nil)
                        .opacity(validationMessage == nil ? 1 : 0.4)
                    }
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
        .fontDesign(.rounded)
        .foregroundStyle(Color.zoneInk)
        .tint(Color.zoneBone)
        .preferredColorScheme(.dark)
    }

    private func timePicker(_ title: String, minute: Binding<Int>) -> some View {
        DatePicker(title, selection: Binding(
            get: { ZoneSchedule.time(minute.wrappedValue) },
            set: { minute.wrappedValue = ZoneSchedule.minute($0) }
        ), displayedComponents: .hourAndMinute)
        .disabled(isRunning)
    }

    private func dayButton(_ day: Int, expanded: Bool) -> some View {
        let selected = schedule.weekdays.contains(day)
        let name = Calendar.current.weekdaySymbols[day - 1]
        let label = HStack {
            Text(expanded ? name : Calendar.current.veryShortWeekdaySymbols[day - 1])
                .font(expanded ? .body : .subheadline.weight(.semibold))
            if expanded {
                Spacer()
            }
        }
        .padding(.horizontal, expanded ? 16 : 0)
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(selected ? Color.zoneBackground : Color.zoneInk)
        .background(selected ? Color.zoneBone : Color.zoneTrack, in: .capsule)
        .contentShape(Rectangle())
        return Group {
            if isRunning {
                label.opacity(0.4)
            } else {
                Button {
                    if selected { schedule.weekdays.remove(day) }
                    else { schedule.weekdays.insert(day) }
                } label: {
                    label
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel(name)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
