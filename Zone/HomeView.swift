import SwiftUI

struct HomeView: View {
    @Environment(ZoneStore.self) private var store
    @State private var scanner = TagScanner()
    // After the first tag scan, ask for its name.
    @State private var namingTag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Entering and leaving the Zone.
    private let change = Animation.smooth(duration: 0.6)

    var body: some View {
        VStack(spacing: 0) {
            ZoneTitle("Zone")
            TimelineView(.periodic(from: .now, by: 1)) { context in
                status(at: context.date)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            Spacer()
            action
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.zoneBackground)
        .tagScanAlert(scanner)
        .sheet(isPresented: $namingTag) {
            NavigationStack {
                TagNameForm(tags: store.tags, backup: false) { namingTag = false }
                    .toolbarBackground(Color.zoneBackground, for: .navigationBar)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .fontDesign(.rounded)
            .tint(Color.zoneBone)
            .preferredColorScheme(.dark)
        }
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
                            .animation(change, value: barFraction(at: now))
                    }
            }
            .frame(height: 4)
            .padding(.top, 26)
            VStack(spacing: 0) {
                if store.profiles.all.count > 1 {
                    ProfileMenu()
                }
                if let since = store.zonedSince {
                    Group {
                        row("Session start", since.formatted(date: .omitted, time: .shortened))
                        row("Total today", zoneTimeText(stats.today))
                    }
                    .transition(enterExit)
                } else if let relockAt = store.relockAt {
                    row("Locks again in", zoneTimeText((max(0, relockAt.timeIntervalSince(now)) / 60).rounded(.up) * 60))
                        .transition(enterExit)
                }
            }
            .padding(.top, 14)
        }
    }

    private func bigTime(_ time: TimeInterval) -> some View {
        let seconds = Int(time)
        return VStack(alignment: .leading, spacing: -33) {
            bigLine("\(seconds / 3600)", unit: "h")
            bigLine(String(format: "%02d", seconds / 60 % 60), unit: "m")
            bigLine(String(format: "%02d", seconds % 60), unit: "s")
        }
        .animation(.smooth(duration: 0.4), value: seconds)
    }

    private func bigLine(_ number: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(number)
                .contentTransition(.numericText())
                .font(.system(size: 120, weight: .bold))
                .tracking(-5)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 38, weight: .semibold))
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

    private var enterExit: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }

    // One button for every state, so only its text changes.
    private var action: some View {
        let title = store.registeredTagID == nil ? "Register your tag" : store.isZoned ? "Scan tag to leave" : "Enter the Zone"
        return Button {
            Task { await act() }
        } label: {
            Text(title)
                .id(title)
                .transition(.opacity)
        }
        .buttonStyle(ZoneButtonStyle())
        .disabled(store.registeredTagID != nil && !store.isZoned && !store.hasBlockedItems)
    }

    private func act() async {
        if store.registeredTagID == nil {
            if let id = await scanner.scan() {
                do {
                    try store.registerTag(id)
                    namingTag = true
                } catch { scanner.errorMessage = error.localizedDescription }
            }
        } else if store.isZoned {
            guard let id = await scanner.scan() else { return }
            guard store.isRegisteredTag(id) else {
                scanner.errorMessage = "That is not your Zone tag."
                return
            }
            withAnimation(change) { store.leaveZone() }
        } else {
            withAnimation(change) { store.enterZone() }
        }
    }
}
