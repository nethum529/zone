import DeviceActivity
import WidgetKit

// iOS runs this extension when a monitored activity starts or ends, even when the app is closed.
final class ZoneMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if ZoneScheduleRuntime.scheduleID(for: activity) != nil {
            ZoneScheduleRuntime.reconcile()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if ZoneScheduleRuntime.scheduleID(for: activity) != nil {
            ZoneScheduleRuntime.reconcile()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        guard activity == ZoneLock.relockActivity,
              ZoneLock.defaults.object(forKey: ZoneLock.Keys.relockAt) != nil
        else { return }
        ZoneLock.lock()
    }
}
