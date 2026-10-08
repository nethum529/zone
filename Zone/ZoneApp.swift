import SwiftUI

@main
struct ZoneApp: App {
    @State private var store = ZoneStore()

    init() {
        // Alert text fields ignore the SwiftUI tint, so set the cursor color here.
        UITextField.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(Color.zoneInk)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                #if DEBUG
                .overlay {
                    if UserDefaults.standard.bool(forKey: "ZoneShieldPreview") {
                        ShieldPreview()
                    }
                }
                #endif
        }
    }
}
