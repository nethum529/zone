import DeviceActivity
import Foundation
import Observation

@MainActor
@Observable
final class ZoneScheduleStore {
    private(set) var schedules: [ZoneSchedule] = []
    private(set) var runningID: UUID?
    private(set) var nextBoundary: Date?
    private let defaults: UserDefaults
    private let startMonitoring: (ZoneSchedule) throws -> Void
    private let stopMonitoring: (UUID) -> Void

    init(
        defaults: UserDefaults = ZoneLock.defaults,
        startMonitoring: @escaping (ZoneSchedule) throws -> Void = { schedule in
            try DeviceActivityCenter().startMonitoring(
                ZoneScheduleRuntime.activity(for: schedule.id),
                during: ZoneScheduleRuntime.deviceSchedule(for: schedule)
            )
        },
        stopMonitoring: @escaping (UUID) -> Void = { id in
            DeviceActivityCenter().stopMonitoring([ZoneScheduleRuntime.activity(for: id)])
        }
    ) {
        self.defaults = defaults
        self.startMonitoring = startMonitoring
        self.stopMonitoring = stopMonitoring
        refresh()
    }

    func refresh(at now: Date = .now) {
        schedules = ZoneScheduleRuntime.schedules(in: defaults).sorted {
            $0.startMinute == $1.startMinute ? $0.id.uuidString < $1.id.uuidString : $0.startMinute < $1.startMinute
        }
        let state = ZoneScheduleRuntime.state(in: defaults)
        let since = defaults.object(forKey: ZoneLock.Keys.zonedSince) as? Date
        let run = state.run.flatMap { $0.zonedSince == since ? $0 : nil }
        runningID = run?.scheduleID
        var boundaries = schedules.compactMap { $0.nextStart(after: now) }
        if let end = run?.interval.end, end > now { boundaries.append(end) }
        nextBoundary = boundaries.min()
    }

    func save(_ draft: ZoneSchedule, at now: Date = .now) throws {
        if let message = draft.validationMessage { throw ScheduleError(message: message) }
        var schedule = draft
        schedule.name = draft.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = try ZoneLock.withStateLock {
            try requireEditable(draft.id, at: now)
            guard let profile = schedule.profile(in: ZoneProfiles.load(from: defaults)) else {
                throw ScheduleError(message: "Choose a profile.")
            }
            schedule.profileID = profile.id
            schedule.effectiveFrom = now
            return ZoneScheduleRuntime.schedules(in: defaults).first { $0.id == draft.id }
        }
        // Monitor calls can start extension callbacks, which need the state lock.
        if schedule.isEnabled { try startMonitoring(schedule) }
        do {
            try ZoneLock.withStateLock {
                try requireEditable(schedule.id, at: now)
                var saved = ZoneScheduleRuntime.schedules(in: defaults)
                if let index = saved.firstIndex(where: { $0.id == schedule.id }) {
                    saved[index] = schedule
                } else {
                    saved.append(schedule)
                }
                defaults.set(try JSONEncoder().encode(saved), forKey: ZoneScheduleRuntime.schedulesKey)
            }
        } catch {
            if schedule.isEnabled {
                if let previous, previous.isEnabled { try? startMonitoring(previous) }
                else { stopMonitoring(schedule.id) }
            }
            throw error
        }
        if !schedule.isEnabled { stopMonitoring(schedule.id) }
        refresh(at: now)
    }

    func delete(_ id: UUID, at now: Date = .now) throws {
        try ZoneLock.withStateLock {
            try requireEditable(id, at: now)
            var saved = ZoneScheduleRuntime.schedules(in: defaults)
            saved.removeAll { $0.id == id }
            defaults.set(try JSONEncoder().encode(saved), forKey: ZoneScheduleRuntime.schedulesKey)
            var state = ZoneScheduleRuntime.state(in: defaults)
            state.handledStarts.removeValue(forKey: id)
            ZoneScheduleRuntime.save(state, in: defaults)
        }
        stopMonitoring(id)
        refresh(at: now)
    }

    private func requireEditable(_ id: UUID, at now: Date) throws {
        let state = ZoneScheduleRuntime.state(in: defaults)
        let since = defaults.object(forKey: ZoneLock.Keys.zonedSince) as? Date
        if let run = state.run, run.scheduleID == id, run.zonedSince == since,
           run.interval.end > now {
            throw ScheduleError(message: "Scan your tag on Home to edit this running schedule.")
        }
    }
}

struct ScheduleError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
