import Charts
import SwiftUI

struct AnalyticsView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // The row with its chart open. Only one is open at a time.
    @State private var open: BarsKind?

    var body: some View {
        VStack(spacing: 0) {
            ZoneTitle("Analytics")
            // Update every minute, so the current session counts as it runs.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let stats = ZoneStats(sessions: store.sessions(at: context.date), now: context.date)
                ScrollView {
                    page(stats)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
    }

    private func page(_ stats: ZoneStats) -> some View {
        let week = stats.lastWeek
        let lengths = stats.weekSessions.map(\.duration)
        let change = changeText(week, from: stats.weekBefore).map { ", \($0.lowercased()) from the 7 before" } ?? ""
        return VStack(spacing: 0) {
            Readout(value: zoneTimeText(week), detail: "Last 7 days\(change)")
            VStack(spacing: 0) {
                section(.hours, "Today", value: zoneTimeText(stats.today), stats: stats)
                section(.week, "Average a day", value: zoneTimeText(week / 7), stats: stats)
                section(.month, "This month", value: zoneTimeText(stats.monthSoFar), note: changeText(stats.monthSoFar, from: stats.lastMonthSoFar), stats: stats)
            }
            .buttonStyle(ZoneRowStyle())
            .padding(.bottom, 20)
            ZoneRow("Average session", value: zoneTimeText(lengths.isEmpty ? 0 : lengths.reduce(0, +) / Double(lengths.count))) { EmptyView() }
            ZoneRow("Longest session", value: zoneTimeText(lengths.max() ?? 0)) { EmptyView() }
        }
    }

    // A row that opens its chart under it.
    private func section(_ kind: BarsKind, _ label: String, value: String, note: String? = nil, stats: ZoneStats) -> some View {
        let isOpen = open == kind
        return VStack(spacing: 0) {
            Button {
                // With reduced motion the chart shows at once.
                withAnimation(reduceMotion ? nil : .smooth(duration: isOpen ? 0.35 : 0.45)) {
                    open = isOpen ? nil : kind
                }
            } label: {
                ZoneRow(label, value: value, note: note) {
                    ZoneCaret().rotationEffect(.degrees(isOpen ? 90 : 0))
                }
            }
            .accessibilityValue(isOpen ? "Chart shown" : "")
            // The chart slides down from under the row, inside the space that opens.
            VStack(spacing: 0) {
                if isOpen {
                    Bars(kind: kind, items: items(kind, stats))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
        }
    }

    private func items(_ kind: BarsKind, _ stats: ZoneStats) -> [(day: Date, time: TimeInterval)] {
        switch kind {
        case .hours: stats.hours(on: stats.now).map { ($0.hour, $0.time) }
        case .week: stats.lastDays(7)
        case .month: stats.monthDays()
        }
    }

    // "Up 12%" or "Down 5%". Nothing when there is no time to compare with.
    private func changeText(_ time: TimeInterval, from before: TimeInterval) -> String? {
        guard before > 0 else { return nil }
        let percent = Int(((time - before) / before * 100).rounded())
        return percent >= 0 ? "Up \(percent)%" : "Down \(-percent)%"
    }
}

private let bubbleAnimation = Animation.smooth(duration: 0.3)

private extension View {
    // The bubble is a tooltip: it goes away by itself.
    func hidesSelection(_ selected: Binding<Date?>) -> some View {
        task(id: selected.wrappedValue) {
            guard selected.wrappedValue != nil,
                  (try? await Task.sleep(for: .seconds(1.5))) != nil
            else { return }
            withAnimation(bubbleAnimation) { selected.wrappedValue = nil }
        }
    }

    // Grows out of the bar it points at. With reduced motion it only fades.
    func bubbleTransition(reduceMotion: Bool) -> some View {
        transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
    }
}

private struct Readout: View {
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.zone(size: 40, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
            Text(detail)
                .font(.zone(size: 15))
                .foregroundStyle(Color.zoneMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 84, alignment: .top)
    }
}

// The total and its hour or day, shown over the bar the user taps.
private struct Bubble: View {
    let time: TimeInterval
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text(zoneTimeText(time))
                .font(.zone(size: 16, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.zone(size: 12))
        }
        .foregroundStyle(Color.zoneBackground)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.zoneInk, in: .rect(cornerRadius: 10))
    }
}

// The three charts: the hours of today, the last 7 days, and the days of this month.
private enum BarsKind {
    case hours, week, month

    var unit: Calendar.Component { self == .hours ? .hour : .day }

    // From the start of a bar to its middle.
    var half: TimeInterval { self == .hours ? 1800 : 12 * 3600 }

    func label(_ date: Date) -> String {
        switch self {
        case .hours: date.formatted(.dateTime.hour())
        case .week, .month: Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }
}

// Bars like Screen Time. The week has a line at the daily average. Tap a bar for its total.
private struct Bars: View {
    let kind: BarsKind
    let items: [(day: Date, time: TimeInterval)]
    @State private var selected: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let average = items.reduce(0) { $0 + $1.time } / Double(max(1, items.count))
        // Room above the tallest bar for the bubble.
        let top = max(1, (items.map(\.time).max() ?? 0) / 3600) * 1.3
        let radius: CGFloat = kind == .week ? 5 : 3
        Chart {
            ForEach(items, id: \.day) { item in
                BarMark(
                    x: .value("Time", item.day, unit: kind.unit),
                    y: .value("Hours", item.time / 3600)
                )
                .foregroundStyle(Color.zoneBone)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: 1, bottomTrailingRadius: 1, topTrailingRadius: radius))
                .opacity(selected == nil || selected == item.day ? 1 : 0.35)
            }
            if kind == .week {
                RuleMark(y: .value("Average", average / 3600))
                    .foregroundStyle(Color.zoneBone.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .chartXAxis { xAxis }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onTapGesture { location in
                        guard let plot = proxy.plotFrame else { return }
                        let x = location.x - geo[plot].origin.x
                        guard let date: Date = proxy.value(atX: x),
                              let start = Calendar.current.dateInterval(of: kind.unit, for: date)?.start,
                              let item = items.first(where: { $0.day == start }),
                              // An hour with no time has no bar to point at.
                              kind != .hours || item.time > 0
                        else { return }
                        withAnimation(bubbleAnimation) { selected = selected == start ? nil : start }
                    }
                if let selected, let item = items.first(where: { $0.day == selected }), let plot = proxy.plotFrame,
                   let x = proxy.position(forX: selected.addingTimeInterval(kind.half)),
                   let y = proxy.position(forY: item.time / 3600) {
                    let frame = geo[plot]
                    // A point on top of the bar. The bubble sits above it and stays inside the chart.
                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(alignment: .bottom) {
                            Bubble(time: item.time, label: kind.label(item.day))
                                .padding(.bottom, 6)
                        }
                        .offset(x: frame.minX + min(max(x, 48), frame.width - 48), y: frame.minY + y)
                        .bubbleTransition(reduceMotion: reduceMotion)
                }
            }
        }
        .frame(height: 150)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .hidesSelection($selected)
    }

    @AxisContentBuilder private var xAxis: some AxisContent {
        switch kind {
        case .hours:
            AxisMarks(values: .stride(by: .hour, count: 6)) {
                AxisValueLabel(format: .dateTime.hour())
                    .foregroundStyle(Color.zoneMute)
            }
        case .week:
            AxisMarks(values: .stride(by: .day)) {
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    .foregroundStyle(Color.zoneMute)
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) {
                AxisValueLabel(format: .dateTime.day(), centered: true)
                    .foregroundStyle(Color.zoneMute)
            }
        }
    }
}
