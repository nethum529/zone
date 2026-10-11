import DeviceActivity
import WidgetKit

// iOS runs this extension when a monitored activity starts or ends, even when the app is closed.
final class ZoneMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if ZoneScheduleRuntime.scheduleID(for: activity) != nil {
            ZoneScheduleRuntime.reconcile()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        relockIfDue(activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if ZoneScheduleRuntime.scheduleID(for: activity) != nil {
            ZoneScheduleRuntime.reconcile()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        relockIfDue(activity)
    }

    // The relock activity starts at the relock time. Its end is a second chance.
    // A callback more than a minute before the relock time does not lock.
    private func relockIfDue(_ activity: DeviceActivityName) {
        guard activity == ZoneLock.relockActivity,
              let relockAt = ZoneLock.defaults.object(forKey: ZoneLock.Keys.relockAt) as? Date,
              relockAt.timeIntervalSinceNow < 60
        else { return }
        ZoneLock.lock()
    }
}
