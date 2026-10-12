import FamilyControls
import SwiftUI

// The first run: Screen Time access, the first profile, the tag name, then one scan.
// The scan saves the tag and starts the first Zone.
struct OnboardingView: View {
    @Environment(ZoneStore.self) private var store
    @State private var step = Step.profile
    @State private var scanner = TagScanner()
    @State private var picking = false
    // The name from the name step. The scan saves the tag with it.
    @State private var tagName: String?
    #if DEBUG
    @State private var replaySelection = FamilyActivitySelection()
    @State private var replayPickerProfileID: UUID?
    #endif

    private enum Step { case profile, tagName, scan }

    var body: some View {
        NavigationStack {
            Group {
                if !store.hasScreenTimeAccess {
                    access
                } else {
                    switch step {
                    case .profile: profile
                    case .tagName: TagNameForm(name: tagName) { tagName = $0 } done: { go(to: .scan) }
                    case .scan: scan
                    }
                }
            }
            .transition(.opacity)
            // Keep the bar on every step, so the title does not move when Skip shows.
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.zoneBone)
        .familyActivityPicker(isPresented: $picking, selection: pickerSelection)
        #if DEBUG
        .onChange(of: picking) { _, shown in
            if !shown, let id = replayPickerProfileID {
                store.renewReplaySelection(replaySelection, for: id)
                replayPickerProfileID = nil
                replaySelection = FamilyActivitySelection()
            }
        }
        #endif
        .tagScanAlert(scanner)
    }

    private var access: some View {
        page("Zone", "Zone blocks the apps you choose until you scan your tag again. It needs Screen Time access to do this.") {
            Button(store.isRequestingAuthorization ? "Waiting for Screen Time..." : "Allow Screen Time access") {
                Task { await store.requestAuthorization() }
            }
            .disabled(store.isRequestingAuthorization)
        } rows: {
            if let error = store.authorizationError {
                Text(error)
                    .foregroundStyle(Color.zoneMute)
            }
        }
    }

    // The default profile blocks social apps. iOS only lets the user choose apps, so the list opens with a hint.
    @ViewBuilder private var profile: some View {
        #if DEBUG
        if let saved = store.replayProfile {
            page(saved.name, "Screen Time cleared app access. Choose this profile's apps again.") {
                Button("Choose apps", action: openPicker)
                    .disabled(store.isRequestingAuthorization)
            } rows: {
                Button(action: openPicker) {
                    ZoneRow("Blocked apps", value: appsText(saved.selection))
                }
                .buttonStyle(ZoneRowStyle())
                .disabled(store.isRequestingAuthorization)
            }
        } else {
            firstProfile
        }
        #else
        firstProfile
        #endif
    }

    private var firstProfile: some View {
        page(profileTitle, profileHint) {
            Button(store.isRequestingAuthorization ? "Waiting for Screen Time..." : (store.hasBlockedItems ? "Next" : "Choose apps")) {
                if store.hasBlockedItems { go(to: .tagName) } else { openPicker() }
            }
            .disabled(store.isRequestingAuthorization)
        } rows: {
            Button(action: openPicker) {
                ZoneRow("Blocked apps", value: appsText(store.selection))
            }
            .buttonStyle(ZoneRowStyle())
            .disabled(store.isRequestingAuthorization)
        }
    }

    private var profileTitle: String {
        #if DEBUG
        if store.isReplayingSetup { return store.profiles.current.name }
        #endif
        return "Your first profile"
    }

    private var profileHint: String {
        #if DEBUG
        if store.isReplayingSetup { return "Your saved profile is ready. Continue to your tag." }
        #endif
        return "Start with your social apps. In the list, tap the circle next to Social, then the check."
    }

    private var scan: some View {
        page("Scan your tag", "Hold the top of your iPhone near your tag. Your apps are blocked right away. Scan it again to leave.") {
            Button("Scan tag") {
                Task { await register() }
            }
        }
    }

    private func register() async {
        guard let id = await scanner.scan() else { return }
        do {
            try store.registerTag(id, name: tagName)
            #if DEBUG
            if store.isReplayingSetup {
                try store.finishReplay()
                return
            }
            #endif
            store.enterZone()
        } catch {
            scanner.errorMessage = error.localizedDescription
        }
    }

    private var pickerSelection: Binding<FamilyActivitySelection> {
        #if DEBUG
        if replayPickerProfileID != nil { return $replaySelection }
        #endif
        return Binding(get: { store.selection }, set: { store.selection = $0 })
    }

    private func openPicker() {
        #if DEBUG
        replayPickerProfileID = store.replayProfile?.id
        replaySelection = FamilyActivitySelection()
        #endif
        picking = true
    }

    private func go(to next: Step) {
        withAnimation(.smooth(duration: 0.3)) { step = next }
    }

    private func page(
        _ title: String,
        _ text: String,
        @ViewBuilder button: () -> some View,
        @ViewBuilder rows: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZoneTitle(title)
            Text(text)
                .foregroundStyle(Color.zoneMute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            rows()
                .font(.zone(size: 17))
                .padding(.horizontal, 24)
                .padding(.top, 12)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            button()
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .background(Color.zoneBackground)
        }
        .background(Color.zoneBackground)
    }
}
