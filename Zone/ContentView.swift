import CoreNFC
import FamilyControls
import SwiftUI

struct ContentView: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        if store.authorization == .approved {
            MainView()
        } else {
            OnboardingView()
        }
    }
}

private struct OnboardingView: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Zone")
                .font(.largeTitle.bold())
            Text("Zone blocks the apps you choose until you tap your tag again. It needs Screen Time access to do this.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Allow Screen Time access") {
                Task { await store.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }
}

private struct MainView: View {
    @Environment(ZoneStore.self) private var store
    @State private var tagReader = TagReader()
    @State private var showingPicker = false
    @State private var showingEmergencyConfirm = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 24) {
            Spacer()
            status
            Spacer()
            if store.registeredTagID == nil {
                Button("Register your tag") { Task { await registerTag() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Text("Hold your phone near the tag you want to use.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(store.isZoned ? "Leave the Zone" : "Enter the Zone") {
                    Task { await toggleZone() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!store.isZoned && !store.hasBlockedItems)
            }
            Button(pickerLabel) { showingPicker = true }
                .disabled(store.isZoned)
            if store.isZoned {
                Button("Emergency exit (\(store.emergencyExitsLeft) left)", role: .destructive) {
                    showingEmergencyConfirm = true
                }
                .disabled(store.emergencyExitsLeft == 0)
                .font(.footnote)
            }
        }
        .padding(32)
        .familyActivityPicker(isPresented: $showingPicker, selection: $store.selection)
        .confirmationDialog(
            "Leave without your tag?",
            isPresented: $showingEmergencyConfirm,
            titleVisibility: .visible
        ) {
            Button("Use an emergency exit", role: .destructive) { store.emergencyExit() }
        } message: {
            Text("You have \(store.emergencyExitsLeft) emergency exits left. They do not come back.")
        }
        .alert("Zone", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var status: some View {
        VStack(spacing: 12) {
            Image(systemName: store.isZoned ? "lock.fill" : "lock.open")
                .font(.system(size: 64))
                .foregroundStyle(store.isZoned ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
            Text(store.isZoned ? "In the Zone" : "Not in the Zone")
                .font(.largeTitle.bold())
            if let since = store.zonedSince {
                Text(since, style: .timer)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pickerLabel: String {
        let count = store.selection.applicationTokens.count
            + store.selection.categoryTokens.count
            + store.selection.webDomainTokens.count
        return count == 0 ? "Choose apps to block" : "Blocking \(count) item\(count == 1 ? "" : "s")"
    }

    private func registerTag() async {
        do {
            let id = try await tagReader.scan(prompt: "Hold your phone near your Zone tag.")
            store.registerTag(id)
        } catch {
            show(error)
        }
    }

    private func toggleZone() async {
        do {
            let id = try await tagReader.scan(prompt: "Hold your phone near your Zone tag.")
            guard store.isRegisteredTag(id) else {
                errorMessage = "That is not your Zone tag."
                return
            }
            withAnimation {
                if store.isZoned { store.leaveZone() } else { store.enterZone() }
            }
        } catch {
            show(error)
        }
    }

    private func show(_ error: Error) {
        // The user closed the scan sheet. This is not an error to show.
        if let nfcError = error as? NFCReaderError, nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            return
        }
        errorMessage = error.localizedDescription
    }
}
