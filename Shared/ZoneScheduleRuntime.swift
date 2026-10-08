import DeviceActivity
import Foundation

enum ZoneScheduleRuntime {
    static let schedulesKey = "zoneSchedules"
    static let stateKey = "zoneScheduleState"
    static let activityPrefix = "zone.schedule."

    static func schedules(in defaults: UserDefaults = ZoneLock.defaults) -> [ZoneSchedule] {
        defaults.data(forKey: schedulesKey)
            .flatMap { try? JSONDecoder().decode([ZoneSchedule].self, from: $0) } ?? []
    }

    static func state(in defaults: UserDefaults = ZoneLock.defaults) -> ZoneScheduleState {
        defaults.data(forKey: stateKey)
            .flatMap { try? JSONDecoder().decode(ZoneScheduleState.self, from: $0) } ?? .init()
    }

    static func save(_ state: ZoneScheduleState, in defaults: UserDefaults = ZoneLock.defaults) {
        defaults.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }

    static func activity(for id: UUID) -> DeviceActivityName {
        DeviceActivityName(activityPrefix + id.uuidString)
    }

    static func scheduleID(for activity: DeviceActivityName) -> UUID? {
        guard activity.rawValue.hasPrefix(activityPrefix) else { return nil }
        return UUID(uuidString: String(activity.rawValue.dropFirst(activityPrefix.count)))
    }

    // One daily monitor per schedule. The start callback checks the chosen weekdays.
    static func deviceSchedule(for schedule: ZoneSchedule) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.startMinute / 60, minute: schedule.startMinute % 60),
            intervalEnd: DateComponents(hour: schedule.endMinute / 60, minute: schedule.endMinute % 60),
            repeats: true
        )
    }

    static func reconcile(at now: Date = .now, in defaults: UserDefaults = ZoneLock.defaults) {
        ZoneLock.withStateLock {
            reconcile(at: now, defaults: defaults, canEnter: { profile in
                let selection = profile.selection
                return defaults.string(forKey: ZoneLock.Keys.tagID) != nil
                    && (!selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
                        || !selection.webDomainTokens.isEmpty)
            },
                      lock: { ZoneLock.applyLock(at: $0, in: defaults) }, unlock: { ZoneLock.applyUnlock(at: $0, in: defaults) })
        }
    }

    static func reconcile(
        at now: Date, defaults: UserDefaults, canEnter: (ZoneProfile) -> Bool,
        lock: (Date) -> Void, unlock: (Date) -> Void
    ) {
        var state = state(in: defaults)
        var since = defaults.object(forKey: ZoneLock.Keys.zonedSince) as? Date
        if let ended = state.finish(at: now, zonedSince: since) {
            if let previous = ended.previousProfileID {
                // The schedule took over a Zone the user entered. Give the profile back and stay in the Zone.
                var profiles = ZoneProfiles.load(from: defaults)
                profiles.choose(previous)
                profiles.save(to: defaults)
                lock(ended.zonedSince)
            } else {
                unlock(ended.interval.end)
                since = nil
            }
        }
        let sessions = defaults.data(forKey: ZoneLock.Keys.sessions)
            .flatMap { try? JSONDecoder().decode([ZoneSession].self, from: $0) } ?? []
        // Earlier starts win when callbacks arrive together.
        let schedules = schedules(in: defaults).sorted {
            let left = $0.interval(at: now)?.start ?? .distantFuture
            let right = $1.interval(at: now)?.start ?? .distantFuture
            return left == right ? $0.id.uuidString < $1.id.uuidString : left < right
        }
        var profiles = ZoneProfiles.load(from: defaults)
        for schedule in schedules {
            let profile = schedule.profile(in: profiles)
            let occupied = schedule.interval(at: now).map { interval in
                sessions.contains { $0.start <= interval.start && interval.start < $0.end }
            } ?? false
            if let started = state.begin(schedule, at: now, zonedSince: since,
                                         canEnter: profile.map(canEnter) ?? false, wasZonedAtStart: occupied),
               let profile {
                if since != nil { state.run?.previousProfileID = profiles.currentID }
                profiles.choose(profile.id)
                profiles.save(to: defaults)
                lock(started.zonedSince)
                since = started.zonedSince
            }
        }
        save(state, in: defaults)
    }
}
