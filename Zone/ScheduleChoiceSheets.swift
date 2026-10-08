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
    @State private var input: ScheduleTimeInput
    @FocusState private var field: Field?

    private enum Field { case hour, minute }

    init(title: String, minute: Binding<Int>) {
        self.title = title
        _minute = minute
        _input = State(initialValue: ScheduleTimeInput(value: minute.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle(title)
                ScrollView {
                    VStack(spacing: 0) {
                        numberRow("Hour", text: $input.hour, field: .hour)
                        numberRow("Minute", text: $input.minute, field: .minute)
                        if !input.uses24HourClock {
                            HStack(spacing: 16) {
                                Text("Period").foregroundStyle(Color.zoneMute)
                                Spacer()
                                periodButton("AM", isPM: false)
                                periodButton("PM", isPM: true)
                            }
                            .frame(minHeight: 52)
                            .padding(.top, 24)
                        }
                        if input.value == nil {
                            Text(input.validationMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.zoneMute)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)
                        }
                    }
                    .font(.body)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Set time") {
                    guard let value = input.value else { return }
                    minute = value
                    dismiss()
                }
                .buttonStyle(ZoneButtonStyle())
                .disabled(input.value == nil)
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

    private func numberRow(_ title: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 16) {
            Text(title).foregroundStyle(Color.zoneMute)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .fontWeight(.semibold)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
                .focused($field, equals: field)
                .accessibilityLabel(title)
                .accessibilityIdentifier("schedule-time-\(title.lowercased())")
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
        .onTapGesture { self.field = field }
    }

    private func periodButton(_ title: String, isPM: Bool) -> some View {
        Button {
            input.isPM = isPM
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(input.isPM == isPM ? Color.zoneBackground : Color.zoneInk)
                .frame(minWidth: 56, minHeight: 44)
                .background(input.isPM == isPM ? Color.zoneBone : Color.zoneTrack, in: .zoneButton)
        }
        .buttonStyle(ZoneRowStyle())
        .accessibilityAddTraits(input.isPM == isPM ? .isSelected : [])
    }
}
