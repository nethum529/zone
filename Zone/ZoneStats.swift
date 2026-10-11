import Foundation

// Totals and streaks from the Zone sessions.
// A session that crosses midnight counts on each day for the part on that day.
struct ZoneStats {
    let sessions: [ZoneSession]
    let now: Date
    let calendar: Calendar

    init(sessions: [ZoneSession], now: Date = .now, calendar: Calendar = .current) {
        self.sessions = sessions
        self.now = now
        self.calendar = calendar
    }

    var today: TimeInterval { time(on: now) }

    var thisWeek: TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return time(in: week)
    }

    // Days in a row with time in the Zone, up to today.
    // A day with no time yet today does not break the streak.
    var streak: Int {
        guard let first = sessions.map(\.start).min() else { return 0 }
        var day = calendar.startOfDay(for: now)
        if time(on: day) == 0 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        var count = 0
        while day >= calendar.startOfDay(for: first), time(on: day) > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    // The last n days, oldest first, with the time in the Zone on each day.
    func lastDays(_ n: Int) -> [(day: Date, time: TimeInterval)] {
        let today = calendar.startOfDay(for: now)
        return (0..<n).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return (day, time(on: day))
        }
    }

    // Every day in the month of now, first day first, with the time in the Zone on each day.
    func monthDays() -> [(day: Date, time: TimeInterval)] {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return [] }
        let count = calendar.range(of: .day, in: .month, for: now)?.count ?? 0
        return (0..<count).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: month.start)!
            return (day, time(on: day))
        }
    }

    // The last 7 days up to now, and the 7 days before them.
    var lastWeek: TimeInterval { time(in: DateInterval(start: weekStart, end: max(weekStart, now))) }
    var weekBefore: TimeInterval { time(in: DateInterval(start: calendar.date(byAdding: .day, value: -7, to: weekStart)!, end: weekStart)) }

    // Sessions with time in the last 7 days.
    var weekSessions: [ZoneSession] { sessions.filter { $0.end > weekStart } }

    // This month up to now, and the same part of last month.
    var monthSoFar: TimeInterval {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return time(in: DateInterval(start: month.start, end: now))
    }

    var lastMonthSoFar: TimeInterval {
        guard let month = calendar.dateInterval(of: .month, for: now),
              let start = calendar.date(byAdding: .month, value: -1, to: month.start)
        else { return 0 }
        let end = min(start.addingTimeInterval(now.timeIntervalSince(month.start)), month.start)
        return time(in: DateInterval(start: start, end: end))
    }

    // Each hour of the day, first hour first, with the time in the Zone in that hour.
    func hours(on day: Date) -> [(hour: Date, time: TimeInterval)] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        var hours: [(hour: Date, time: TimeInterval)] = []
        var hour = interval.start
        while hour < interval.end {
            let next = calendar.date(byAdding: .hour, value: 1, to: hour)!
            hours.append((hour, time(in: DateInterval(start: hour, end: next))))
            hour = next
        }
        return hours
    }

    func time(on day: Date) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return time(in: interval)
    }

    private var weekStart: Date {
        calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
    }

    private func time(in interval: DateInterval) -> TimeInterval {
        sessions.reduce(0) { total, session in
            let start = max(session.start, interval.start)
            let end = min(session.end, interval.end)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
