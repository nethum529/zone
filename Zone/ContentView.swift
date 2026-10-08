import CoreNFC
import FamilyControls
import SwiftUI

struct ContentView: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        Group {
            if store.authorization == .approved {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Color.zoneInk)
        .preferredColorScheme(.dark)
        .task { await store.watchAuthorization() }
    }
}

private struct OnboardingView: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Zone")
                .font(.system(size: 34, weight: .bold))
            Text("Zone blocks the apps you choose until you tap your tag again. It needs Screen Time access to do this.")
                .foregroundStyle(Color.zoneMute)
            Spacer()
            Button("Allow Screen Time access") {
                Task { await store.requestAuthorization() }
            }
            .buttonStyle(ZoneButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
    }
}

private enum ZoneTab {
    case home, analytics, settings
}

private struct MainView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ZoneTab.home

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", image: tab == .home ? "house-fill" : "house", value: .home) {
                HomeView()
            }
            Tab("Analytics", image: tab == .analytics ? "chart-bar-fill" : "chart-bar", value: .analytics) {
                AnalyticsView()
            }
            Tab("Settings", image: tab == .settings ? "gear-six-fill" : "gear-six", value: .settings) {
                SettingsView()
            }
        }
        .tint(Color.zoneInk)
        .onChange(of: scenePhase) {
            if scenePhase == .active { store.refresh() }
        }
        .task(id: store.relockAt) {
            // Lock on time when the app is open.
            guard let relockAt = store.relockAt else { return }
            try? await Task.sleep(for: .seconds(max(0, relockAt.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            withAnimation { store.refresh() }
        }
    }
}

// Scans the tag and shows what went wrong, if anything.
@MainActor
@Observable
final class TagScanner {
    var errorMessage: String?
    private let reader = TagReader()
    private var isScanning = false

    // Returns nil when the scan failed or the user closed the scan sheet.
    func scan() async -> String? {
        // A second tap while a scan runs does nothing.
        guard !isScanning else { return nil }
        isScanning = true
        defer { isScanning = false }
        do {
            return try await reader.scan(prompt: "Hold your phone near your Zone tag.")
        } catch {
            // The user closed the scan sheet, or it closed by itself. The sheet already showed this.
            if let nfcError = error as? NFCReaderError,
               [.readerSessionInvalidationErrorUserCanceled, .readerSessionInvalidationErrorSessionTimeout].contains(nfcError.code) {
                return nil
            }
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

extension View {
    func tagScanAlert(_ scanner: TagScanner) -> some View {
        alert("Zone", isPresented: .constant(scanner.errorMessage != nil)) {
            Button("OK") { scanner.errorMessage = nil }
        } message: {
            Text(scanner.errorMessage ?? "")
        }
    }
}
