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
        .syncsLockScreen(zonedSince: store.zonedSince)
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

private enum ZoneTab: CaseIterable {
    case home, analytics, settings

    var title: String {
        switch self {
        case .home: "Home"
        case .analytics: "Analytics"
        case .settings: "Settings"
        }
    }
}

// Three words at the bottom, lined up with the page edges. The current tab is in ink.
private struct ZoneTabBar: View {
    @Binding var tab: ZoneTab

    var body: some View {
        HStack {
            ForEach(ZoneTab.allCases, id: \.self) { item in
                if item != .home { Spacer() }
                Button(item.title) { tab = item }
                    .foregroundStyle(item == tab ? Color.zoneInk : Color.zoneMute)
                    .frame(height: 48)
                    .contentShape(.rect)
                    .accessibilityAddTraits(item == tab ? .isSelected : [])
            }
        }
        .font(.system(size: 17, weight: .semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .background(Color.zoneBackground)
    }
}

private struct MainView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = ZoneTab.home

    var body: some View {
        // The system tab bar is hidden. ZoneTabBar replaces it, and TabView keeps each tab's state.
        TabView(selection: $tab) {
            Tab(value: .home) { withBar(HomeView()) }
            Tab(value: .analytics) { withBar(AnalyticsView()) }
            Tab(value: .settings) { withBar(SettingsView()) }
        }
        .modifier(ScheduleRefresh())
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

    // An inset on the TabView does not reach the tabs, so each tab gets its own bar.
    private func withBar(_ content: some View) -> some View {
        content
            .toolbarVisibility(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ZoneTabBar(tab: $tab)
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
    #if DEBUG && targetEnvironment(simulator)
    let simulatedScan = SimulatedTagScan()
    #endif

    // Returns nil when the scan failed or the user closed the scan sheet.
    func scan(prompt: String = "Hold your phone near your Zone tag.") async -> String? {
        // A second tap while a scan runs does nothing.
        guard !isScanning else { return nil }
        isScanning = true
        defer { isScanning = false }
        #if DEBUG && targetEnvironment(simulator)
        return await simulatedScan.scan(prompt: prompt)
        #else
        do {
            return try await reader.scan(prompt: prompt)
        } catch {
            // The user closed the scan sheet, or it closed by itself. The sheet already showed this.
            if let nfcError = error as? NFCReaderError,
               [.readerSessionInvalidationErrorUserCanceled, .readerSessionInvalidationErrorSessionTimeout].contains(nfcError.code) {
                return nil
            }
            errorMessage = error.localizedDescription
            return nil
        }
        #endif
    }
}

extension View {
    func tagScanAlert(_ scanner: TagScanner) -> some View {
        alert("Zone", isPresented: .constant(scanner.errorMessage != nil)) {
            Button("OK") { scanner.errorMessage = nil }
        } message: {
            Text(scanner.errorMessage ?? "")
        }
        #if DEBUG && targetEnvironment(simulator)
        .modifier(SimulatedTagScanPresenter(scan: scanner.simulatedScan))
        #endif
    }
}
