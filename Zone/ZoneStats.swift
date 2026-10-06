import Foundation

struct ZoneSession: Codable, Hashable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

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

    func time(on day: Date) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return time(in: interval)
    }

    private func time(in interval: DateInterval) -> TimeInterval {
        sessions.reduce(0) { total, session in
            let start = max(session.start, interval.start)
            let end = min(session.end, interval.end)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
