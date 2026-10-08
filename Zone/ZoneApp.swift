import SwiftUI

@main
struct ZoneApp: App {
    @State private var store = ZoneStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                #if DEBUG
                .overlay {
                    if UserDefaults.standard.bool(forKey: "ZoneShieldPreview") {
                        ShieldPreview(zonedSince: store.zonedSince)
                    }
                }
                #endif
        }
    }
}
