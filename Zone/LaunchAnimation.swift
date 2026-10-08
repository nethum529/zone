import SwiftUI

// The launch animation, shown each time the app opens. 0.84 s after a 0.15 s hold.
// The two halves of the mark slide in and latch with a click, then the mark
// swells and fades into Home. Reduce Motion: the mark fades in, then a crossfade, 0.7 s.
// The values come from the "the latch" prototype in zone-launch/chosen.md.
struct LaunchAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.start
    @State private var halvesVisible = false
    @State private var isShowing = true

    private enum Step: Int, Comparable {
        case start, latched, clicked, markGone, layerGone

        static func < (a: Step, b: Step) -> Bool { a.rawValue < b.rawValue }
    }

    // House curve of the prototype: cubic-bezier(0.2, 0.7, 0.2, 1).
    private static let exit = Animation.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.24)

    func body(content: Content) -> some View {
        content
            .scaleEffect(step >= .layerGone || reduceMotion ? 1 : 0.97)
            .overlay {
                if isShowing {
                    layer
                }
            }
            .task { await play() }
    }

    private var layer: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.28
            let height = width * ZoneMarkHalf.viewBox.height / ZoneMarkHalf.viewBox.width
            let travel = step >= .latched || reduceMotion ? 0 : height * 0.34
            ZStack {
                ZoneMarkHalf(side: .left)
                    .offset(y: -travel)
                ZoneMarkHalf(side: .right)
                    .offset(y: travel)
            }
            .foregroundStyle(Color.zoneBone)
            .frame(width: width, height: height)
            .opacity(halvesVisible ? 1 : 0)
            .opacity(step >= .markGone ? 0 : 1)
            .scaleEffect(markScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.zoneBackground)
        .ignoresSafeArea()
        .opacity(step >= .layerGone ? 0 : 1)
        .allowsHitTesting(step < .layerGone)
        .accessibilityHidden(true)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: step) { _, new in
            new == .clicked && !reduceMotion
        }
    }

    private var markScale: CGFloat {
        if reduceMotion { return 1 }
        switch step {
        case .start, .latched: return 0.9
        case .clicked: return 1
        case .markGone, .layerGone: return 1.18
        }
    }

    private func play() async {
        // The app draws its first frames slowly, which froze the first 0.09 s of the spring.
        // So wait 0.15 s on the plain background first. It looks the same as the launch screen.
        try? await Task.sleep(for: .milliseconds(150))
        let begin = ContinuousClock.now
        func at(_ ms: Int, _ animation: Animation, _ next: Step) async {
            try? await Task.sleep(until: begin + .milliseconds(ms))
            withAnimation(animation) { step = next }
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) { halvesVisible = true }
            await at(450, .easeInOut(duration: 0.25), .layerGone)
            try? await Task.sleep(until: begin + .milliseconds(700))
        } else {
            // The halves fade in over the first 0.04 s while the spring moves them.
            withAnimation(.linear(duration: 0.04)) { halvesVisible = true }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.55)) { step = .latched }
            // The halves first meet at 0.14 s: the click.
            await at(140, .spring(response: 0.22, dampingFraction: 0.5), .clicked)
            await at(560, Self.exit, .markGone)
            await at(600, Self.exit, .layerGone)
            try? await Task.sleep(until: begin + .milliseconds(840))
        }
        isShowing = false
    }
}

extension View {
    func launchAnimation() -> some View {
        modifier(LaunchAnimation())
    }
}
