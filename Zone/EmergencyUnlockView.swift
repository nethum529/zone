import SwiftUI

struct EmergencyUnlockSettingsRow<Label: View>: View {
    @Environment(ZoneStore.self) private var store
    @State private var isPresented = false
    private let label: (Int) -> Label

    init(@ViewBuilder label: @escaping (Int) -> Label) {
        self.label = label
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.isZoned {
                Button { isPresented = true } label: {
                    label(EmergencyUnlockAllowance(defaults: ZoneLock.defaults).remaining(at: .now))
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            EmergencyUnlockView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.zoneBackground)
        }
    }
}

private struct EmergencyUnlockView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var statusFocused: Bool
    @State private var attempt = EmergencyUnlockAttempt()
    @State private var uptime = ProcessInfo.processInfo.systemUptime
    @State private var remaining = EmergencyUnlockAllowance(defaults: ZoneLock.defaults).remaining(at: .now)
    @State private var wasInterrupted = false

    private var isWaiting: Bool {
        if case .waiting = attempt.phase { return true }
        return false
    }

    private var isHolding: Bool {
        if case .holding = attempt.phase { return true }
        return false
    }

    private var isComplete: Bool { attempt.phase == .completed }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isComplete ? "Out of the Zone" : "Emergency unlock")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .contentTransition(.opacity)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($statusFocused)

                    if isComplete {
                        if store.superZone {
                            Text("Zone will not relock this time.")
                                .foregroundStyle(Color.zoneMute)
                                .padding(.top, 24)
                        }
                    } else if remaining == 0 {
                        exhausted
                    } else {
                        countdown
                    }

                    Spacer(minLength: 40)

                    HStack {
                        Text("Left this month")
                            .foregroundStyle(Color.zoneMute)
                        Spacer()
                        Text("\(remaining)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .padding(.bottom, 24)

                    if isComplete {
                        Button("Done") { dismiss() }
                            .buttonStyle(ZoneButtonStyle())
                    } else if remaining == 0 {
                        Button("Close") { dismiss() }
                            .buttonStyle(ZoneButtonStyle())
                    } else if isWaiting {
                        Button("Cancel unlock") { cancelWait() }
                            .buttonStyle(ZoneButtonStyle())
                    } else {
                        holdButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.zoneBackground)
        .foregroundStyle(Color.zoneInk)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .transaction { if reduceMotion { $0.animation = nil } }
        .onChange(of: scenePhase) {
            if scenePhase != .active { cancelWait() }
            remaining = EmergencyUnlockAllowance(defaults: ZoneLock.defaults).remaining(at: .now)
        }
        .onDisappear {
            attempt.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: isWaiting) {
            UIApplication.shared.isIdleTimerDisabled = isWaiting
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isWaiting) { _, waiting in waiting }
        .sensoryFeedback(.success, trigger: isComplete) { _, completed in completed }
        .task(id: attempt.phase) {
            guard isHolding || isWaiting else { return }
            while !Task.isCancelled {
                tick()
                do { try await Task.sleep(for: .milliseconds(isHolding ? 30 : 200)) }
                catch { return }
            }
        }
    }

    private var countdown: some View {
        let seconds = attempt.secondsRemaining(at: uptime)
        return VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 104, weight: .bold, design: .rounded))
                .tracking(-4)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: seconds)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel("\(seconds / 60) minutes, \(seconds % 60) seconds remaining")
                .padding(.top, 32)

            Capsule()
                .fill(Color.zoneTrack)
                .overlay {
                    Capsule()
                        .fill(Color.zoneBone)
                        .scaleEffect(x: Double(seconds) / EmergencyUnlockAttempt.waitDuration, anchor: .leading)
                }
                .frame(height: 4)
                .padding(.top, 18)
                .accessibilityHidden(true)

            Text(wasInterrupted ? "Wait reset. No unlock used." : isWaiting
                 ? "Leaving the app restarts the wait."
                 : "Hold, then keep this screen open for 3 minutes.")
                .foregroundStyle(Color.zoneMute)
                .padding(.top, 24)
        }
    }

    private var exhausted: some View {
        Group {
            if let reset = Calendar.current.dateInterval(of: .month, for: .now)?.end {
                Text("3 more on \(reset.formatted(.dateTime.month(.wide).day())). You can still leave with your Zone tag.")
                    .foregroundStyle(Color.zoneMute)
            }
        }
        .padding(.top, 40)
    }

    private var holdButton: some View {
        Button {} label: {
            Text(isHolding ? "Keep holding" : "Hold for 3 seconds")
        }
        .buttonStyle(EmergencyHoldStyle(
            progress: attempt.holdProgress(at: uptime),
            pressed: { pressed in
                if pressed { beginHold() }
                else { attempt.releaseHold() }
            }
        ))
        .accessibilityLabel("Start emergency unlock")
        .accessibilityHint("Double tap to start. Keep this screen open for 3 minutes.")
        .accessibilityAction {
            // Assistive input keeps the same delay without a continuous touch.
            beginHold()
        }
    }

    private func beginHold() {
        guard scenePhase == .active, store.isZoned, remaining > 0 else { return }
        wasInterrupted = false
        uptime = ProcessInfo.processInfo.systemUptime
        attempt.beginHold(at: uptime)
    }

    private func cancelWait() {
        if isWaiting || isHolding { wasInterrupted = true }
        attempt.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        guard scenePhase == .active else { return }
        uptime = ProcessInfo.processInfo.systemUptime
        remaining = EmergencyUnlockAllowance(defaults: ZoneLock.defaults).remaining(at: .now)
        guard store.isZoned || isComplete else {
            cancelWait()
            dismiss()
            return
        }
        attempt.advance(at: uptime)
        if isWaiting && attempt.secondsRemaining(at: uptime) == 0 {
            let unlocked = withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.4)) {
                store.emergencyUnlock(attempt: &attempt, uptime: uptime)
            }
            if unlocked {
                remaining = EmergencyUnlockAllowance(defaults: ZoneLock.defaults).remaining(at: .now)
                statusFocused = true
            } else {
                cancelWait()
            }
        }
    }
}

private struct EmergencyHoldStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let progress: Double
    let pressed: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.zoneBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .frame(minHeight: 56)
            .background {
                Color.zoneBone
                    .overlay(alignment: .leading) {
                        Color.zoneBackground.opacity(0.2)
                            .scaleEffect(x: progress, anchor: .leading)
                    }
                    .clipShape(.capsule)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(.smooth(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed(configuration.isPressed) }
    }
}
