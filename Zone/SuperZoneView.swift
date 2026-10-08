import SwiftUI

// Super Zone and its relock time, on their own page.
struct SuperZoneView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Super Zone")
                VStack(spacing: 0) {
                    Toggle(isOn: $store.superZone) {
                        Text("Super Zone")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.zoneInk)
                    }
                    .toggleStyle(ZoneToggleStyle(size: 20))
                    .frame(height: 64)
                    Menu {
                        Picker("Relock after", selection: $store.relockMinutes) {
                            ForEach(ZoneStore.relockChoices, id: \.self) { Text("\($0) min") }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Relock after")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(store.relockMinutes) min")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Image("caret-up-down")
                                .resizable()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(Color.zoneMute)
                                // The caret ink ends 4 pt inside its frame. Line it up with the switch edge.
                                .padding(.trailing, -4)
                        }
                        .font(.system(size: 20))
                        .foregroundStyle(Color.zoneInk)
                        .frame(height: 64)
                        .contentShape(.rect)
                    }
                    .buttonStyle(ZoneRowStyle())
                    .disabled(!store.superZone)
                }
                .disabled(store.relockAt != nil)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                Spacer()
            }
            .schedulePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
