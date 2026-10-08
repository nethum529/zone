import Foundation

struct ZoneSession: Codable, Hashable {
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
