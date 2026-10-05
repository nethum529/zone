import DeviceActivity

// iOS runs this extension when a monitored activity starts or ends, even when the app is closed.
final class ZoneMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == ZoneLock.relockActivity,
              ZoneLock.defaults.object(forKey: ZoneLock.Keys.relockAt) != nil
        else { return }
        ZoneLock.lock()
    }
}
