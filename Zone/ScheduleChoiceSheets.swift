import SwiftUI

struct ScheduleProfileSheet: View {
    @Environment(ZoneStore.self) private var zone
    @Environment(\.dismiss) private var dismiss
    @Binding var profileID: ZoneProfile.ID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Profile")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(zone.profiles.all) { profile in
                            Button {
                                profileID = profile.id
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    Text(profile.name)
                                    Spacer(minLength: 16)
                                    if profile.id == (profileID ?? zone.profiles.currentID) {
                                        Text("Selected").foregroundStyle(Color.zoneMute)
                                    }
                                }
                                .frame(minHeight: 52)
                                .contentShape(.rect)
                            }
                            .accessibilityAddTraits(profile.id == (profileID ?? zone.profiles.currentID) ? .isSelected : [])
                        }
                    }
                    .font(.body)
                    .buttonStyle(ZoneRowStyle())
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .schedulePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ScheduleDaysSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weekdays: Set<Int>
    @State private var selection: Set<Int>

    init(weekdays: Binding<Set<Int>>) {
        _weekdays = weekdays
        _selection = State(initialValue: weekdays.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Repeat")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ZoneSchedule.orderedWeekdays, id: \.self) { day in
                            Toggle(isOn: Binding(
                                get: { selection.contains(day) },
                                set: { if $0 { selection.insert(day) } else { selection.remove(day) } }
                            )) {
                                Text(Calendar.current.weekdaySymbols[day - 1]).font(.body)
                            }
                            .toggleStyle(ZoneToggleStyle())
                        }
                        if selection.isEmpty {
                            Text("Choose at least one day.")
                                .font(.footnote)
                                .foregroundStyle(Color.zoneMute)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Set days") {
                    weekdays = selection
                    dismiss()
                }
                .buttonStyle(ZoneButtonStyle())
                .disabled(selection.isEmpty)
                .padding(24)
                .background(Color.zoneBackground)
            }
            .schedulePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ScheduleTimeSheet: View {
    let title: String
    @Binding var minute: Int
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date

    init(title: String, minute: Binding<Int>) {
        self.title = title
        _minute = minute
        _time = State(initialValue: ZoneSchedule.time(minute.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle(title)
                // The iOS wheel: hour, minute, and AM or PM when the clock uses them.
                DatePicker(title, selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                Button("Set time") {
                    minute = ZoneSchedule.minute(time)
                    dismiss()
                }
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .background(Color.zoneBackground)
            }
            .schedulePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
