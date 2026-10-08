import Foundation

extension ZoneSchedule {
    var displayName: String {
        let name = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Schedule" : name
    }

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

struct ScheduleTimeInput {
    var hour: String
    var minute: String
    var isPM: Bool
    let uses24HourClock: Bool

    init(value: Int, uses24HourClock: Bool = ScheduleTimeInput.prefers24HourClock) {
        self.uses24HourClock = uses24HourClock
        let hour = value / 60
        self.hour = String(uses24HourClock ? hour : (hour % 12 == 0 ? 12 : hour % 12))
        minute = String(format: "%02d", value % 60)
        isPM = hour >= 12
    }

    var value: Int? {
        let hours = uses24HourClock ? 0...23 : 1...12
        guard let hour = Int(hour), hours.contains(hour),
              let minute = Int(minute), (0...59).contains(minute) else { return nil }
        let clockHour = uses24HourClock ? hour : hour % 12 + (isPM ? 12 : 0)
        return clockHour * 60 + minute
    }

    var validationMessage: String {
        let hours = uses24HourClock ? 0...23 : 1...12
        if Int(hour).map(hours.contains) != true {
            return "Enter an hour from \(hours.lowerBound) to \(hours.upperBound)."
        }
        return "Enter a minute from 0 to 59."
    }

    private static var prefers24HourClock: Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "h a"
        return !format.contains("a")
    }
}
