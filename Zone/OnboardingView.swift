import FamilyControls
import SwiftUI

// The first run: Screen Time access, the first profile, the tag name, then one scan.
// The scan saves the tag and starts the first Zone.
struct OnboardingView: View {
    @Environment(ZoneStore.self) private var store
    @State private var step = Step.profile
    @State private var scanner = TagScanner()
    @State private var picking = false

    private enum Step { case profile, tagName, scan }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Group {
                if store.authorization != .approved {
                    access
                } else {
                    switch step {
                    case .profile: profile
                    case .tagName: TagNameForm(tags: store.tags, backup: false) { go(to: .scan) }
                    case .scan: scan
                    }
                }
            }
            .transition(.opacity)
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.zoneBone)
        .familyActivityPicker(isPresented: $picking, selection: $store.selection)
        .tagScanAlert(scanner)
    }

    private var access: some View {
        page("Zone", "Zone blocks the apps you choose until you scan your tag again. It needs Screen Time access to do this.") {
            Button("Allow Screen Time access") {
                Task { await store.requestAuthorization() }
            }
        }
    }

    // The default profile blocks social apps. iOS only lets the user choose apps, so the list opens with a hint.
    private var profile: some View {
        page("Your first profile", "Start with your social apps. In the list, tap Social, then Done.") {
            Button(store.hasBlockedItems ? "Next" : "Choose apps") {
                if store.hasBlockedItems { go(to: .tagName) } else { picking = true }
            }
        } rows: {
            Button { picking = true } label: {
                ZoneRow("Blocked apps", value: appsText(store.selection))
            }
            .buttonStyle(ZoneRowStyle())
        }
    }

    private var scan: some View {
        page("Scan your tag", "Hold the top of your iPhone near \(store.tags.mainName ?? "your tag"). Your apps are blocked right away. Scan it again to leave.") {
            Button("Scan tag") {
                Task { await register() }
            }
        }
    }

    private func register() async {
        guard let id = await scanner.scan() else { return }
        do {
            try store.registerTag(id)
            store.enterZone()
        } catch {
            scanner.errorMessage = error.localizedDescription
        }
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
                .font(.system(size: 17))
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
