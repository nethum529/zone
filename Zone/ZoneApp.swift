import SwiftUI

@main
struct ZoneApp: App {
    @State private var store = ZoneStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
