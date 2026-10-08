import Foundation

struct ZoneSchedule: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String?
    var profileID: ZoneProfile.ID?
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var startMinute = 9 * 60
    var endMinute = 17 * 60
    var isEnabled = true
    var effectiveFrom: Date = .now

    var crossesMidnight: Bool { endMinute < startMinute }
    var durationMinutes: Int { (endMinute - startMinute + 1440) % 1440 }

    func profile(in profiles: ZoneProfiles) -> ZoneProfile? {
        profiles.profile(profileID ?? profiles.currentID)
    }

    var validationMessage: String? {
        if weekdays.isEmpty { return "Choose at least one day." }
        if !weekdays.isSubset(of: Set(1...7))
            || !(0..<1440).contains(startMinute) || !(0..<1440).contains(endMinute) {
            return "Choose valid days and times."
        }
        if startMinute == endMinute { return "Choose different start and end times." }
        if durationMinutes < 15 { return "Allow at least 15 minutes in the Zone." }
        return nil
    }

    // Weekdays refer to the day the schedule starts, including overnight schedules.
    func interval(at now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard isEnabled, validationMessage == nil else { return nil }
        let today = calendar.startOfDay(for: now)
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let interval = interval(startingOn: day, calendar: calendar),
                  interval.start >= effectiveFrom,
                  interval.start <= now, now < interval.end
            else { continue }
            return interval
        }
        return nil
    }

    func nextStart(after now: Date, calendar: Calendar = .current) -> Date? {
        guard isEnabled, validationMessage == nil else { return nil }
        let today = calendar.startOfDay(for: max(now, effectiveFrom))
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let interval = interval(startingOn: day, calendar: calendar),
                  interval.start > now, interval.start >= effectiveFrom
            else { continue }
            return interval.start
        }
        return nil
    }

    private func interval(startingOn day: Date, calendar: Calendar) -> DateInterval? {
        guard let start = calendar.date(
            bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0,
            of: day, matchingPolicy: .nextTimePreservingSmallerComponents
        ), let endDay = calendar.date(byAdding: .day, value: crossesMidnight ? 1 : 0, to: day),
        let end = calendar.date(
            bySettingHour: endMinute / 60, minute: endMinute % 60, second: 0,
            of: endDay, matchingPolicy: .nextTimePreservingSmallerComponents
        ), end > start else { return nil }
        return DateInterval(start: start, end: end)
    }
}

struct ZoneScheduleRun: Codable, Equatable {
    let scheduleID: UUID
    let interval: DateInterval
    let zonedSince: Date
}

// Remember each start even when it was skipped or the user left with their tag.
struct ZoneScheduleState: Codable {
    var handledStarts: [UUID: Date] = [:]
    var run: ZoneScheduleRun?

    mutating func begin(
        _ schedule: ZoneSchedule, at now: Date, zonedSince: Date?,
        canEnter: Bool, wasZonedAtStart: Bool = false, calendar: Calendar = .current
    ) -> ZoneScheduleRun? {
        guard let interval = schedule.interval(at: now, calendar: calendar),
              handledStarts[schedule.id] != interval.start else { return nil }
        handledStarts[schedule.id] = interval.start
        guard zonedSince == nil, !wasZonedAtStart, canEnter else { return nil }
        let started = ZoneScheduleRun(scheduleID: schedule.id, interval: interval, zonedSince: now)
        run = started
        return started
    }

    mutating func finish(at now: Date, zonedSince: Date?) -> ZoneScheduleRun? {
        guard let run else { return nil }
        guard run.zonedSince == zonedSince else {
            self.run = nil
            return nil
        }
        guard now >= run.interval.end else { return nil }
        self.run = nil
        return run
    }
}
