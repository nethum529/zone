import FamilyControls
import SwiftUI

struct SettingsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var scanner = TagScanner()
    @State private var showingPicker = false

    var body: some View {
        @Bindable var store = store
        // Only when unlocked, so a new tag or fewer blocked apps cannot be used to leave the Zone.
        let locked = store.isZoned || store.relockAt != nil
        VStack(spacing: 0) {
            ZoneTitle("Settings")
            Form {
                Section {
                    Button { showingPicker = true } label: {
                        row("prohibit-fill", "Blocked apps", value: blockedText)
                    }
                    .disabled(locked)
                    Button {
                        Task {
                            if let id = await scanner.scan() { store.registerTag(id) }
                        }
                    } label: {
                        row("contactless-payment-fill", "Zone tag", value: store.registeredTagID == nil ? "Register" : "Change")
                    }
                    .disabled(locked)
                }
                .listRowBackground(Color.zoneCard)
                Section {
                    Toggle(isOn: $store.superZone) {
                        label("lightning-fill", "Super Zone")
                    }
                    .tint(Color.zoneBone)
                    Picker(selection: $store.relockMinutes) {
                        ForEach(ZoneStore.relockChoices, id: \.self) { Text("\($0) min") }
                    } label: {
                        label("timer-fill", "Relock after")
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
        .familyActivityPicker(isPresented: $showingPicker, selection: $store.selection)
        .tagScanAlert(scanner)
    }

    private var blockedText: String {
        let count = store.selection.applicationTokens.count
            + store.selection.categoryTokens.count
            + store.selection.webDomainTokens.count
        return count == 0 ? "None" : "\(count) app\(count == 1 ? "" : "s")"
    }

    private func label(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(icon)
                .resizable()
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.zoneBone)
                .frame(width: 30, height: 30)
                .background(Color.zoneBone.opacity(0.14), in: .rect(cornerRadius: 9))
            Text(title)
                .foregroundStyle(Color.zoneInk)
        }
    }

    private func row(_ icon: String, _ title: String, value: String) -> some View {
        HStack {
            label(icon, title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.zoneMute)
            Image("caret-right")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.zoneMute)
        }
    }
}
