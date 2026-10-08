import ActivityKit
import Foundation

// The Live Activity for one Zone session. The app and the widget extension both use this.
struct ZoneActivityAttributes: ActivityAttributes {
    // Nothing changes while the session runs. The timer text counts by itself.
    struct ContentState: Codable, Hashable {}

    // When the session started.
    let since: Date
}
