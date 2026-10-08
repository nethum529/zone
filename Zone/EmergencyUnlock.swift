import Foundation

struct EmergencyUnlockAttempt {
    static let holdDuration: TimeInterval = 3
    static let waitDuration: TimeInterval = 180

    enum Phase: Hashable {
        case ready
        case holding(since: TimeInterval)
        case waiting(until: TimeInterval)
        case completed
    }

    private(set) var phase = Phase.ready

    mutating func beginHold(at uptime: TimeInterval) {
        guard phase == .ready else { return }
        phase = .holding(since: uptime)
    }

    mutating func releaseHold() {
        if case .holding = phase { phase = .ready }
    }

    mutating func advance(at uptime: TimeInterval) {
        guard case .holding(let start) = phase,
              uptime - start >= Self.holdDuration else { return }
        phase = .waiting(until: uptime + Self.waitDuration)
    }

    func secondsRemaining(at uptime: TimeInterval) -> Int {
        guard case .waiting(let deadline) = phase else { return Int(Self.waitDuration) }
        return Int(max(0, deadline - uptime).rounded(.up))
    }

    func holdProgress(at uptime: TimeInterval) -> Double {
        guard case .holding(let start) = phase else { return 0 }
        return min(1, max(0, (uptime - start) / Self.holdDuration))
    }

    mutating func complete(at uptime: TimeInterval) -> Bool {
        guard case .waiting(let deadline) = phase, uptime >= deadline else { return false }
        phase = .completed
        return true
    }

    mutating func cancel() {
        guard phase != .completed else { return }
        phase = .ready
    }
}

struct EmergencyUnlockAllowance {
    static let monthlyLimit = 3
    static let storageKey = "emergencyUnlockDates"

    let defaults: UserDefaults

    private var dates: [Date] {
        defaults.array(forKey: Self.storageKey) as? [Date] ?? []
    }

    func remaining(at now: Date, calendar: Calendar = .current) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        // Keep future uses counted if the clock moves back.
        let used = dates.filter { $0 >= month.start }.count
        return max(0, Self.monthlyLimit - used)
    }

    func consume(at now: Date, calendar: Calendar = .current) -> Bool {
        guard remaining(at: now, calendar: calendar) > 0 else { return false }
        defaults.set(dates + [now], forKey: Self.storageKey)
        return true
    }
}
