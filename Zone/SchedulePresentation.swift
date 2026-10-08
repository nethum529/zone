import Foundation

extension ZoneSchedule {
    var daysText: String {
        if weekdays == Set(1...7) { return "Every day" }
        if weekdays == Set(2...6) { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        return Self.orderedWeekdays.filter { weekdays.contains($0) }
            .map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }

    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func time(_ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1,
                                                    hour: minute / 60, minute: minute % 60))!
    }

    static func minute(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }

    var timeText: String {
        "\(Self.time(startMinute).formatted(date: .omitted, time: .shortened)) to \(Self.time(endMinute).formatted(date: .omitted, time: .shortened))"
    }
}
