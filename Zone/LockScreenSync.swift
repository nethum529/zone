import ActivityKit
import SwiftUI
import WidgetKit

// Keeps the Lock Screen in step with the Zone: the Live Activity and the widgets.
// Only the app can start a Live Activity. After a Super Zone relock by the monitor extension,
// the activity starts the next time the app opens.
enum LockScreenSync {
    struct Plan: Equatable {
        // The indexes of the activities to end.
        var end: [Int]
        var start: Bool
    }

    // Keep one running activity for the current session and end all others.
    // iOS ends an activity after 8 hours, so a long session then gets a new one.
    static func plan(zonedSince: Date?, activities: [(since: Date, isActive: Bool)]) -> Plan {
        let keep = zonedSince.flatMap { since in
            activities.firstIndex { $0.isActive && abs($0.since.timeIntervalSince(since)) < 1 }
        }
        return Plan(
            end: activities.indices.filter { $0 != keep },
            start: zonedSince != nil && keep == nil
        )
    }

    static func run(zonedSince: Date?) async {
        let activities = Activity<ZoneActivityAttributes>.activities
        let plan = plan(
            zonedSince: zonedSince,
            activities: activities.map { ($0.attributes.since, $0.activityState == .active) }
        )
        for index in plan.end {
            await activities[index].end(nil, dismissalPolicy: .immediate)
        }
        if plan.start, let zonedSince {
            do {
                _ = try Activity.request(
                    attributes: ZoneActivityAttributes(since: zonedSince),
                    content: ActivityContent(state: .init(), staleDate: nil)
                )
            } catch {
                print("Could not start the Live Activity: \(error)")
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension View {
    // Starts and ends the Live Activity with the Zone, and updates the widgets.
    func syncsLockScreen(zonedSince: Date?) -> some View {
        modifier(LockScreenSyncModifier(zonedSince: zonedSince))
    }
}

private struct LockScreenSyncModifier: ViewModifier {
    let zonedSince: Date?
    @Environment(\.scenePhase) private var scenePhase

    private struct Key: Equatable {
        let zonedSince: Date?
        let isActive: Bool
    }

    // Runs when the Zone starts or ends, and each time the app opens.
    func body(content: Content) -> some View {
        content.task(id: Key(zonedSince: zonedSince, isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            await LockScreenSync.run(zonedSince: zonedSince)
        }
    }
}
