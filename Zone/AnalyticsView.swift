import Charts
import SwiftUI

struct AnalyticsView: View {
    @Environment(ZoneStore.self) private var store
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            ZoneTitle("Analytics")
            // Update every minute, so the current session counts as it runs.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let stats = ZoneStats(sessions: store.sessions(at: context.date), now: context.date)
                TabView(selection: $page) {
                    MonthPage(stats: stats).page().tag(0)
                    WeekPage(stats: stats).page().tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(page == index ? Color.zoneInk : Color(rgb: 0x3A3A42))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
    }
}

private extension View {
    func page() -> some View {
        padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension View {
    // The bubble is a tooltip: it goes away by itself.
    func hidesSelection(_ selected: Binding<Date?>) -> some View {
        task(id: selected.wrappedValue) {
            guard selected.wrappedValue != nil,
                  (try? await Task.sleep(for: .seconds(2))) != nil
            else { return }
            withAnimation(.easeOut(duration: 0.15)) { selected.wrappedValue = nil }
        }
    }
}

private struct Readout: View {
    let value: String
    let detail: String
    var flame = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
            HStack(spacing: 5) {
                if flame {
                    Image("fire-fill")
                        .resizable()
                        .frame(width: 15, height: 15)
                        .foregroundStyle(Color.zoneBone)
                }
                Text(detail)
            }
            .font(.system(size: 15))
            .foregroundStyle(Color.zoneMute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 84, alignment: .top)
    }
}

// The day and its total, shown over the square or bar the user taps.
private struct Bubble: View {
    let day: Date
    let time: TimeInterval

    var body: some View {
        VStack(spacing: 1) {
            Text(zoneTimeText(time))
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
            Text(Calendar.current.isDateInToday(day) ? "Today" : day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                .font(.system(size: 12))
        }
        .foregroundStyle(Color.zoneBackground)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.zoneInk, in: .rect(cornerRadius: 10))
    }
}

// Slide 1: a square for each day of this month, brighter for more time in the Zone.
private struct MonthPage: View {
    let stats: ZoneStats
    @State private var selected: Date?

    private let calendar = Calendar.current

    var body: some View {
        let days = stats.monthDays()
        let total = days.reduce(0) { $0 + $1.time }
        let streak = stats.streak
        VStack(spacing: 0) {
            Readout(value: zoneTimeText(total), detail: "\(streak) day streak", flame: true)
            weekdayHeader
            grid(days)
                .padding(.top, 8)
        }
        .hidesSelection($selected)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 6) {
            ForEach(ordered.indices, id: \.self) { index in
                Text(ordered[index])
                    .font(.system(size: 12))
                    .foregroundStyle(Color.zoneMute)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ days: [(day: Date, time: TimeInterval)]) -> some View {
        let lead = days.first.map { (calendar.component(.weekday, from: $0.day) - calendar.firstWeekday + 7) % 7 } ?? 0
        let cells: [(day: Date, time: TimeInterval)?] = Array(repeating: nil, count: lead) + days.map { $0 }
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        return VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                let row = rows[r]
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { c in
                        if c < row.count, let item = row[c] {
                            square(item, column: c)
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .zIndex(row.contains { $0?.day == selected } ? 1 : 0)
            }
        }
    }

    private func square(_ item: (day: Date, time: TimeInterval), column: Int) -> some View {
        let future = item.day > stats.now
        let isSelected = item.day == selected
        let isToday = calendar.isDate(item.day, inSameDayAs: stats.now)
        let alignment: Alignment = column == 0 ? .topLeading : column == 6 ? .topTrailing : .top
        return RoundedRectangle(cornerRadius: 8)
            .fill(fill(item.time, future: future))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday || isSelected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(Color.zoneInk, lineWidth: 2)
                }
            }
            .opacity(selected == nil || isSelected ? 1 : 0.35)
            .overlay(alignment: alignment) {
                if isSelected {
                    Bubble(day: item.day, time: item.time)
                        .alignmentGuide(.top) { $0[.bottom] + 6 }
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                guard !future else { return }
                withAnimation(.easeOut(duration: 0.1)) { selected = isSelected ? nil : item.day }
            }
            .accessibilityElement()
            .accessibilityLabel(item.day.formatted(date: .complete, time: .omitted))
            .accessibilityValue(zoneTimeText(item.time))
            .accessibilityAddTraits(.isButton)
    }

    private func fill(_ time: TimeInterval, future: Bool) -> Color {
        if future { return Color(rgb: 0x1B1B21) }
        switch time {
        case 0: return Color(rgb: 0x22222A)
        case ..<3600: return Color.zoneBone.opacity(0.3)
        case ..<7200: return Color.zoneBone.opacity(0.6)
        default: return Color.zoneBone
        }
    }
}

// Slide 2: the last 7 days as bars, like Screen Time, with the daily average.
private struct WeekPage: View {
    let stats: ZoneStats
    @State private var selected: Date?

    var body: some View {
        let days = stats.lastDays(7)
        let total = days.reduce(0) { $0 + $1.time }
        let average = total / 7
        // Room above the tallest bar for the bubble.
        let top = max(1, (days.map(\.time).max() ?? 0) / 3600) * 1.3
        VStack(spacing: 0) {
            Readout(value: zoneTimeText(average), detail: "Total \(zoneTimeText(total))")
            Chart {
                ForEach(days, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day, unit: .day),
                        y: .value("Hours", item.time / 3600)
                    )
                    .foregroundStyle(Color.zoneBone)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 5))
                    .opacity(selected == nil || selected == item.day ? 1 : 0.35)
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        if selected == item.day {
                            Bubble(day: item.day, time: item.time)
                        }
                    }
                }
                RuleMark(y: .value("Average", average / 3600))
                    .foregroundStyle(Color.zoneBone.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
            .chartYScale(domain: 0...top)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) {
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Color.zoneMute)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geo[plot].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            let day = Calendar.current.startOfDay(for: date)
                            guard days.contains(where: { $0.day == day }) else { return }
                            withAnimation(.easeOut(duration: 0.1)) { selected = selected == day ? nil : day }
                        }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .hidesSelection($selected)
    }
}
