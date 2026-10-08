import Foundation

// The Zone state that the widgets show, read from the App Group.
struct ZoneSnapshot: Equatable {
    var zonedSince: Date?
    // In Super Zone, the time when Zone locks again.
    var relockAt: Date?
    // Finished sessions.
    var sessions: [ZoneSession]

    var isZoned: Bool { zonedSince != nil }

    // The same suite and keys as ZoneLock. The widget does not build ZoneLock, because it needs Screen Time.
    static func load(from defaults: UserDefaults = UserDefaults(suiteName: "group.com.nethum.zone")!) -> ZoneSnapshot {
        ZoneSnapshot(
            zonedSince: defaults.object(forKey: "zonedSince") as? Date,
            relockAt: defaults.object(forKey: "relockAt") as? Date,
            sessions: defaults.data(forKey: "sessions")
                .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        )
    }

    // The state at a later time. At the relock time the monitor extension enters the Zone again.
    func at(_ date: Date) -> ZoneSnapshot {
        guard zonedSince == nil, let relockAt, relockAt <= date else { return self }
        return ZoneSnapshot(zonedSince: relockAt, relockAt: nil, sessions: sessions)
    }

    // Time in the Zone today, with the current session up to now.
    func today(at now: Date, calendar: Calendar = .current) -> TimeInterval {
        let all = zonedSince.map { sessions + [ZoneSession(start: $0, end: now)] } ?? sessions
        return ZoneStats(sessions: all, now: now, calendar: calendar).today
    }

    // The times after now when the widget changes without the app:
    // at midnight a new day starts, and in Super Zone the Zone starts again.
    func changes(after now: Date, calendar: Calendar = .current) -> [Date] {
        var dates = [calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!]
        if zonedSince == nil, let relockAt, relockAt > now {
            dates.append(relockAt)
        }
        return dates.sorted()
    }
}
