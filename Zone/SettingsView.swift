import SwiftUI

struct SettingsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var scanner = TagScanner()
    @State private var showingProfiles = false

    var body: some View {
        @Bindable var store = store
        // Only when unlocked, so a new tag or fewer blocked apps cannot be used to leave the Zone.
        let locked = store.isZoned || store.relockAt != nil
        VStack(spacing: 0) {
            ZoneTitle("Settings")
            Form {
                Section {
                    Button { showingProfiles = true } label: {
                        ZoneRow("stack-fill", "Profiles", value: store.profiles.current.name)
                    }
                    Button {
                        Task {
                            if let id = await scanner.scan() { store.registerTag(id) }
                        }
                    } label: {
                        ZoneRow("contactless-payment-fill", "Zone tag", value: store.registeredTagID == nil ? "Register" : "Change")
                    }
                    .disabled(locked)
                }
                .listRowBackground(Color.zoneCard)
                Section {
                    Toggle(isOn: $store.superZone) {
                        ZoneRowLabel("lightning-fill", "Super Zone")
                    }
                    .tint(Color.zoneBone)
                    Picker(selection: $store.relockMinutes) {
                        ForEach(ZoneStore.relockChoices, id: \.self) { Text("\($0) min") }
                    } label: {
                        ZoneRowLabel("timer-fill", "Relock after")
                    }
                    .tint(Color.zoneMute)
                } footer: {
                    Text("When you leave, Zone locks again after this time.")
                }
                .disabled(store.relockAt != nil)
                .listRowBackground(Color.zoneCard)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
        .sheet(isPresented: $showingProfiles) { ProfilesView() }
        .tagScanAlert(scanner)
    }
}
