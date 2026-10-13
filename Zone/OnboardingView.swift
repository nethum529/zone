import FamilyControls
import SwiftUI

// Test the tag before setup. Only the final scan saves it and starts a Zone.
struct OnboardingView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.ready
    @State private var scanner = TagScanner()
    @State private var scanning = false
    @State private var picking = false
    @State private var testedID: String?
    @State private var tagName = ""
    @State private var scanError: String?
    #if DEBUG
    @State private var replaySelection = FamilyActivitySelection()
    @State private var replayPickerProfileID: UUID?
    #endif

    private enum Step { case ready, test, verified, failed(TestFailure), purchase, access, profile, scan }
    private enum TestFailure { case unreadable, mismatch }
    private let amazonTags = URL(string: "https://www.amazon.com/s?k=NTAG215+NFC+tags")!

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                switch step {
                case .ready: ready
                case .test: cardTest
                case .verified: verified
                case .failed(let reason): failed(reason)
                case .purchase: purchase
                case .access: access
                case .profile:
                    if store.hasScreenTimeAccess { profile } else { access }
                case .scan:
                    if store.hasScreenTimeAccess { scan } else { access }
                }
            }
            .transition(.opacity)
            .toolbarVisibility(.visible, for: .navigationBar)
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    switch step {
                    case .test, .verified, .failed, .purchase:
                        Button("Back") { clearTest(); go(to: .ready) }
                            .disabled(scanning)
                    case .scan:
                        Button("Back") { go(to: .profile) }
                            .disabled(scanning)
                    default: EmptyView()
                    }
                }
            }
        }
        .tint(Color.zoneBone)
        .familyActivityPicker(isPresented: $picking, selection: pickerSelection)
        .onChange(of: store.hasScreenTimeAccess) { _, allowed in
            if allowed, case .access = step { go(to: .profile) }
        }
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
        .task(id: scanning) {
            guard scanning else { return }
            if case .scan = step { await register() } else { await testCard() }
            scanning = false
        }
    }

    private var ready: some View {
        page("Have a tag?", "Scan a tag to block apps. Scan it again to leave. You may already have one.") {
            VStack(spacing: 12) {
                Button("Test my card or tag", action: startTest)
                secondary("I need a tag") { go(to: .purchase) }
            }
        } rows: {
            VStack(spacing: 0) {
                plainRow("NFC sticker or key fob", action: startTest)
                plainRow("amiibo figure or card", action: startTest)
                plainRow("Student or work ID", action: startTest)
                plainRow("Transit or old hotel card", action: startTest)
            }
        }
    }

    private var cardTest: some View {
        page("Test your card", "Hold one card near the top of your iPhone. This test does not block apps or change the card.") {
            Button("Scan card") { scanning = true }
                .disabled(scanning)
        }
    }

    private var verified: some View {
        page("This tag is ready", "It read the same ID each time. Keep this tag. You will use it to leave a Zone.") {
            Button("Continue") { go(to: .access) }
        } rows: {
            plainRow("Test another card", action: startTest)
        }
    }

    private func failed(_ reason: TestFailure) -> some View {
        page(reason == .mismatch ? "This card changes its ID" : "Could not read this card",
             reason == .mismatch
             ? "This card shows a new ID at each read, so Zone cannot use it. Try another tag."
             : "Hold one card near the top of your iPhone and try again. Some cards cannot be read.") {
            Button("Try again", action: startTest)
        } rows: {
            VStack(alignment: .leading, spacing: 12) {
                plainRow("Try another card", action: startTest)
                Link(destination: amazonTags) { ZoneRow("Find tags on Amazon", value: "") }
                    .buttonStyle(ZoneRowStyle())
            }
        }
    }

    private var purchase: some View {
        page("A tag for about $7", "A 10-pack of NTAG215 tags is $6.99 on Amazon before shipping and tax. Prices can change. You only need one.") {
            VStack(spacing: 12) {
                Link("Find tags on Amazon", destination: amazonTags)
                secondary("I have a tag to test", action: startTest)
            }
        }
    }

    private var access: some View {
        page("Enable app blocking", "Zone needs Screen Time access to block the apps you choose.") {
            Button(store.isRequestingAuthorization ? "Waiting for Screen Time..." : "Continue") {
                if store.hasScreenTimeAccess {
                    go(to: .profile)
                } else {
                    Task {
                        await store.requestAuthorization()
                        if store.hasScreenTimeAccess { go(to: .profile) }
                    }
                }
            }
            .disabled(store.isRequestingAuthorization)
        } rows: {
            if let error = store.authorizationError {
                Text(error).foregroundStyle(Color.zoneMute)
            }
        }
    }

    @ViewBuilder private var profile: some View {
        #if DEBUG
        if let saved = store.replayProfile {
            page(saved.name, "Screen Time cleared app access. Choose this profile's apps again.") {
                Button("Choose apps", action: openPicker)
                    .disabled(store.isRequestingAuthorization)
            } rows: {
                Button(action: openPicker) { ZoneRow("Blocked apps", value: appsText(saved.selection)) }
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
        page("Choose your distractions", "Pick the apps you want to block. Social is a good start.") {
            Button(store.isRequestingAuthorization ? "Waiting for Screen Time..." : (store.hasBlockedItems ? "Continue" : "Choose apps")) {
                if store.hasBlockedItems { go(to: .scan) } else { openPicker() }
            }
            .disabled(store.isRequestingAuthorization)
        } rows: {
            Button(action: openPicker) { ZoneRow("Blocked apps", value: appsText(store.selection)) }
                .buttonStyle(ZoneRowStyle())
                .disabled(store.isRequestingAuthorization)
        }
    }

    private var scan: some View {
        page("Scan to start", "Hold the top of your iPhone near the tag you tested. Scanning blocks your chosen apps. Scan again to leave.") {
            Button("Scan tag") { scanning = true }
                .disabled(scanning || store.isRequestingAuthorization || !store.hasBlockedItems)
        } rows: {
            TagNameForm.Field(name: $tagName, label: "Tag name", placeholder: "Optional")
            if let scanError { Text(scanError).foregroundStyle(Color.zoneMute) }
        }
    }

    private func testCard() async {
        scanner.errorMessage = nil
        // One sheet reads the card twice. Zone matches the ID, so the ID must stay the same.
        guard let ids = await scanner.scanTwice(prompt: "Hold the top of your iPhone near one card or tag.") else {
            if scanner.errorMessage != nil {
                scanner.errorMessage = nil
                clearTest()
                go(to: .failed(.unreadable))
            }
            return
        }
        guard !Task.isCancelled else { return }
        guard ids.allSatisfy({ $0 == ids[0] }) else { clearTest(); go(to: .failed(.mismatch)); return }
        testedID = ids[0]
        go(to: .verified)
    }

    private func register() async {
        guard store.hasScreenTimeAccess, store.hasBlockedItems, let testedID else { return }
        scanError = nil
        guard let id = await scanner.scan(prompt: "Hold the top of your iPhone near the tag you tested."), !Task.isCancelled else { return }
        guard id == testedID else {
            scanError = "Use the tag you tested. This scan does not match."
            return
        }
        do {
            let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            try store.registerTag(id, name: name.isEmpty ? nil : name)
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
        guard store.hasScreenTimeAccess, !store.isRequestingAuthorization else { return }
        #if DEBUG
        replayPickerProfileID = store.replayProfile?.id
        replaySelection = FamilyActivitySelection()
        #endif
        picking = true
    }

    private func clearTest() { testedID = nil }
    private func startTest() { clearTest(); go(to: .test) }

    private func go(to next: Step) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { step = next }
    }

    private func plainRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { ZoneRow(title, value: "") }
            .buttonStyle(ZoneRowStyle())
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.zone(size: 16))
            .foregroundStyle(Color.zoneBone)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(.rect)
            .buttonStyle(.plain)
    }

    private func page(
        _ title: String,
        _ text: String,
        @ViewBuilder button: () -> some View,
        @ViewBuilder rows: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        GeometryReader { geometry in
            ScrollView {
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
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .safeAreaInset(edge: .bottom) {
            button()
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .background(Color.zoneBackground)
        }
        .background(Color.zoneBackground)
    }
}
