import Charts
import SwiftUI

struct StatsView: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        // Update every minute, so the current session counts as it runs.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let stats = ZoneStats(sessions: store.sessions(at: context.date), now: context.date)
            List {
                Section {
                    HStack {
                        stat("Today", Self.format(stats.today))
                        stat("This week", Self.format(stats.thisWeek))
                        stat("Streak", stats.streak == 1 ? "1 day" : "\(stats.streak) days")
                    }
                }
                Section("Last 7 days") {
                    Chart(stats.lastDays(7), id: \.day) { item in
                        BarMark(
                            x: .value("Day", item.day, unit: .day),
                            y: .value("Hours", item.time / 3600)
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) {
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                }
                if !store.sessions.isEmpty {
                    Section("Sessions") {
                        ForEach(store.sessions.suffix(20).reversed(), id: \.self) { session in
                            HStack {
                                Text(session.start, format: .dateTime.weekday().day().month().hour().minute())
                                Spacer()
                                Text(Self.format(session.duration))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Stats")
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private static func format(_ time: TimeInterval) -> String {
        Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
