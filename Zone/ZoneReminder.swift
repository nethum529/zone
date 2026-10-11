import SwiftUI
import UserNotifications

// When Super Zone is off, this notification asks the user to enter the Zone again,
// 15 minutes after they leave. Entering the Zone removes it (see ZoneLock.applyLock).
@MainActor
final class ZoneReminder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ZoneReminder()
    private static let category = "reminder"
    private static let enterAction = "enter"
    private static let snoozeAction = "snooze"

    private var store: ZoneStore?
    private var center: UNUserNotificationCenter { .current() }

    private var delay: TimeInterval {
        #if DEBUG
        // For tests in the simulator: launch with -ZoneReminderSeconds 20.
        let seconds = UserDefaults.standard.double(forKey: "ZoneReminderSeconds")
        if seconds > 0 { return seconds }
        #endif
        return 15 * 60
    }

    // Call this at launch, before iOS sends a tap or a button press.
    func start(store: ZoneStore) {
        self.store = store
        center.delegate = self
        // Without .foreground, the button enters the Zone and does not open the app.
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.category,
                actions: [
                    UNNotificationAction(identifier: Self.enterAction, title: "Enter the Zone"),
                    UNNotificationAction(identifier: Self.snoozeAction, title: "Remind me in 15 min"),
                ],
                intentIdentifiers: []
            )
        ])
    }

    // iOS asks for permission the first time, just after the user leaves the Zone.
    func schedule() async {
        guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Zone"
        content.body = "Reminder that you turned off Super Zone. Enter the Zone?"
        content.categoryIdentifier = Self.category
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: ZoneLock.reminderID, content: content, trigger: trigger))
    }

    // A tap and the Enter the Zone button both enter the Zone.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await handle(response.actionIdentifier)
    }

    private func handle(_ action: String) async {
        switch action {
        case Self.snoozeAction:
            await schedule()
        case Self.enterAction, UNNotificationDefaultActionIdentifier:
            // The same change as the Home button, so the user sees it when the app opens.
            withAnimation(.smooth(duration: 0.6)) { store?.enterZone() }
        default:
            break
        }
    }
}
