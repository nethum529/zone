import SwiftUI

struct HomeView: View {
    @Environment(ZoneStore.self) private var store
    @State private var scanner = TagScanner()

    var body: some View {
        VStack(spacing: 0) {
            ZoneTitle("Zone")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                status(at: context.date)
            }
            .padding(.horizontal, 24)
            .padding(.top, 36)
            Spacer()
            action
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
        .tagScanAlert(scanner)
    }

    // In the Zone: this session, with a full bar.
    // Not in the Zone: today's total. In Super Zone the bar empties until Zone locks again.
    private func status(at now: Date) -> some View {
        let stats = ZoneStats(sessions: store.sessions(at: now), now: now)
        let shown = store.zonedSince.map { now.timeIntervalSince($0) } ?? stats.today
        return VStack(alignment: .leading, spacing: 0) {
            bigTime(shown)
            GeometryReader { geo in
                Capsule()
                    .fill(Color.zoneTrack)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.zoneInk)
                            .frame(width: geo.size.width * barFraction(at: now))
                    }
            }
            .frame(height: 4)
            .padding(.top, 26)
            VStack(spacing: 0) {
                if let since = store.zonedSince {
                    row("Session start", since.formatted(date: .omitted, time: .shortened))
                    row("Total today", zoneTimeText(stats.today))
                } else if let relockAt = store.relockAt {
                    row("Locks again in", zoneTimeText((max(0, relockAt.timeIntervalSince(now)) / 60).rounded(.up) * 60))
                }
            }
            .padding(.top, 14)
        }
    }

    private func bigTime(_ time: TimeInterval) -> some View {
        let minutes = Int(time) / 60
        return VStack(alignment: .leading, spacing: -41) {
            bigLine("\(minutes / 60)", unit: "h")
            bigLine(String(format: "%02d", minutes % 60), unit: "m")
        }
    }

    private func bigLine(_ number: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(number)
                .font(.system(size: 150, weight: .bold))
                .tracking(-7)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(Color.zoneMute)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private func barFraction(at now: Date) -> Double {
        if store.isZoned { return 1 }
        guard let relockAt = store.relockAt else { return 0 }
        let total = Double(store.relockMinutes * 60)
        return min(1, max(0, relockAt.timeIntervalSince(now) / total))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.zoneMute)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: 17))
        .frame(height: 30)
    }

    @ViewBuilder
    private var action: some View {
        if store.registeredTagID == nil {
            Button("Register your tag") {
                Task {
                    if let id = await scanner.scan() { store.registerTag(id) }
                }
            }
            .buttonStyle(ZoneButtonStyle())
        } else if store.isZoned {
            Button("Scan tag to leave") {
                Task {
                    guard let id = await scanner.scan() else { return }
                    guard store.isRegisteredTag(id) else {
                        scanner.errorMessage = "That is not your Zone tag."
                        return
                    }
                    withAnimation { store.leaveZone() }
                }
            }
            .buttonStyle(ZoneButtonStyle())
        } else {
            Button("Enter the Zone") {
                withAnimation { store.enterZone() }
            }
            .buttonStyle(ZoneButtonStyle())
            .disabled(!store.hasBlockedItems)
        }
    }
}
