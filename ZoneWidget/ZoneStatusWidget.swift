import SwiftUI
import WidgetKit

// Shows if you are in the Zone and your time today, on the Home Screen and the Lock Screen.
// A tap opens the app.
struct ZoneStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZoneStatus", provider: ZoneStatusProvider()) { entry in
            ZoneStatusView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(Color.zoneBackground, for: .widget)
        }
        .configurationDisplayName("Zone")
        .description("See if you are in the Zone and your time today.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ZoneStatusEntry: TimelineEntry {
    let date: Date
    let isZoned: Bool
    // Time in the Zone today, at date.
    let today: TimeInterval

    init(date: Date, isZoned: Bool, today: TimeInterval) {
        self.date = date
        self.isZoned = isZoned
        self.today = today
    }

    init(_ snapshot: ZoneSnapshot, at date: Date) {
        let state = snapshot.at(date)
        self.init(date: date, isZoned: state.isZoned, today: state.today(at: date))
    }

    // In the Zone it counts up by itself, so the widget does not need a new entry each minute.
    var todayText: Text {
        if isZoned {
            Text(.durationOffset(to: date.addingTimeInterval(-today)), format: .units(allowed: [.hours, .minutes], width: .narrow))
        } else {
            Text(zoneTimeText(today))
        }
    }
}

struct ZoneStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZoneStatusEntry {
        ZoneStatusEntry(date: .now, isZoned: true, today: 2 * 3600 + 16 * 60)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZoneStatusEntry) -> Void) {
        completion(ZoneStatusEntry(.load(), at: .now))
    }

    // One entry now, and one at each time the widget changes by itself.
    // The app asks for a new timeline when the Zone starts or ends.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ZoneStatusEntry>) -> Void) {
        let snapshot = ZoneSnapshot.load()
        let now = Date.now
        let entries = ([now] + snapshot.changes(after: now)).map { ZoneStatusEntry(snapshot, at: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ZoneStatusView: View {
    let entry: ZoneStatusEntry
    @Environment(\.widgetFamily) private var family

    private var status: String { entry.isZoned ? "In the Zone" : "Not in the Zone" }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    // The mark shows when you are in the Zone, like in the circular widget.
    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            if entry.isZoned {
                ZoneMark(size: 22, color: .zoneBone)
            }
            Spacer(minLength: 0)
            entry.todayText
                .font(.system(size: 34, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Color.zoneInk)
            Text("Today")
                .font(.system(size: 15))
                .foregroundStyle(Color.zoneMute)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // The mark shows when you are in the Zone, like in the island.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isZoned {
                VStack(spacing: 2) {
                    ZoneMark(size: 14)
                        .widgetAccentable()
                    circularToday
                }
            } else {
                circularToday
            }
        }
    }

    // The time today. A long time wraps to two lines.
    private var circularToday: some View {
        entry.todayText
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(status)
                .font(.headline)
                .widgetAccentable()
            Text("\(entry.todayText) today")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: Text {
        if entry.isZoned {
            Text("In the Zone, \(entry.todayText) today")
        } else {
            Text("\(entry.todayText) today")
        }
    }
}
