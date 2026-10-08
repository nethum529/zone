import SwiftUI
import UIKit

// Swipe a row left to delete it, as in Profiles and Schedules.
// The row does not move. Its value slot (check, status, caret) fades away
// and a red Delete comes in at the same place. Tap Delete to delete.
// One row in a list can be open at a time.
extension View {
    func swipeToDelete<ID: Hashable>(
        _ id: ID, open: Binding<ID?>, enabled: Bool, delete: @escaping () -> Void
    ) -> some View {
        modifier(SwipeToDelete(id: id, open: open, enabled: enabled, delete: delete))
    }

    // The row's name. It dims while Delete shows.
    func swipeLabel() -> some View { modifier(SwipePart(isValue: false)) }

    // The row's value slot. It slides left and fades while Delete comes in.
    func swipeValue() -> some View { modifier(SwipePart(isValue: true)) }
}

// The drag that shows Delete in full.
private let swipeWidth: CGFloat = 64

private extension EnvironmentValues {
    // 0 when the row shows its value, 1 when it shows Delete.
    @Entry var swipeProgress: Double = 0
}

private struct SwipePart: ViewModifier {
    let isValue: Bool
    @Environment(\.swipeProgress) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isValue {
            content
                .opacity(1 - progress)
                .offset(x: reduceMotion ? 0 : -14 * progress)
        } else {
            content.opacity(1 - 0.45 * progress)
        }
    }
}

private struct SwipeToDelete<ID: Hashable>: ViewModifier {
    let id: ID
    @Binding var open: ID?
    let enabled: Bool
    let delete: () -> Void
    @State private var progress: Double = 0
    // The progress when the drag started, or nil when no drag runs.
    @State private var dragStart: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isOpen: Bool { open == id }

    func body(content: Content) -> some View {
        content
            .environment(\.swipeProgress, progress)
            .overlay {
                if progress > 0 {
                    ZStack(alignment: .trailing) {
                        // While Delete shows, a tap on the row only closes it.
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { settle(open: false) }
                        Button(action: delete) {
                            Text("Delete")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.zoneDelete)
                                .padding(.leading, 16)
                                .padding(.trailing, 24)
                                .frame(maxHeight: .infinity)
                                .contentShape(.rect)
                        }
                        .buttonStyle(ZoneRowStyle())
                        .opacity(progress)
                        .offset(x: reduceMotion ? 0 : 16 * (1 - progress))
                        .allowsHitTesting(progress > 0.9)
                    }
                }
            }
            .gesture(SwipePan(enabled: enabled, changed: dragChanged, ended: dragEnded))
            .onChange(of: isOpen) { _, isOpen in
                // Another row opened, or the list closed this one.
                if !isOpen, dragStart == nil, progress > 0 { settle(open: false) }
            }
            .onChange(of: enabled) { _, enabled in
                if !enabled { settle(open: false) }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isOpen) { _, isOpen in isOpen }
            .accessibilityActions {
                if enabled { Button("Delete", action: delete) }
            }
    }

    private func dragChanged(_ translation: CGFloat) {
        if dragStart == nil {
            dragStart = isOpen ? 1 : 0
            if !isOpen { open = nil }
        }
        let x = -(dragStart ?? 0) * swipeWidth + translation
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { progress = min(1, max(0, -x / swipeWidth)) }
    }

    private func dragEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        let x = -(dragStart ?? 0) * swipeWidth + translation
        dragStart = nil
        // Project where a flick is going (deceleration rate 0.99), then snap.
        let projected = x + velocity * 0.099
        settle(open: projected < -swipeWidth / 2, velocity: -velocity / swipeWidth)
    }

    // Spring to shown or hidden from where the row is now, with the finger's speed.
    private func settle(open shown: Bool, velocity: Double = 0) {
        let target: Double = shown ? 1 : 0
        let distance = target - progress
        let relative = abs(distance) > 0.001 ? velocity / distance : 0
        let spring = Animation.interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: relative)
        withAnimation(reduceMotion ? nil : spring) { progress = target }
        if shown { open = id } else if isOpen { open = nil }
    }
}

// A pan that starts only when the finger moves more sideways than up or down,
// so a vertical move still scrolls the list.
private struct SwipePan: UIGestureRecognizerRepresentable {
    let enabled: Bool
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ pan: UIPanGestureRecognizer, context: Context) {
        pan.isEnabled = enabled
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let x = pan.translation(in: pan.view).x
        switch pan.state {
        case .began, .changed: changed(x)
        case .ended: ended(x, pan.velocity(in: pan.view).x)
        case .cancelled, .failed: ended(x, 0)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let move = pan.translation(in: pan.view)
            let speed = pan.velocity(in: pan.view)
            let d = move == .zero ? speed : move
            return abs(d.x) > abs(d.y)
        }
    }
}

// The quiet line after a swipe delete: "Sleep deleted" and Undo.
// The delete is final only when the line hides, after 4 s, or when the page goes away.
// Put it on the page's bottom button. It sits 16 pt above the button.
extension View {
    func undoLine<Item: Identifiable & Equatable>(
        _ pending: Binding<Item?>, text: @escaping (Item) -> String, commit: @escaping (Item) -> Void
    ) -> some View {
        modifier(UndoLine(pending: pending, text: text, commit: commit))
    }
}

private struct UndoLine<Item: Identifiable & Equatable>: ViewModifier {
    @Binding var pending: Item?
    let text: (Item) -> String
    let commit: (Item) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let item = pending {
                    HStack(spacing: 0) {
                        Text(text(item))
                            .foregroundStyle(Color.zoneMute)
                            .lineLimit(1)
                        Spacer(minLength: 16)
                        Button {
                            withAnimation(.smooth(duration: 0.34)) { pending = nil }
                        } label: {
                            Text("Undo")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.zoneBone)
                                .frame(height: 44)
                                .padding(.leading, 16)
                                .contentShape(.rect)
                        }
                        .buttonStyle(ZoneRowStyle())
                    }
                    .font(.system(size: 15))
                    .frame(height: 44)
                    .padding(.horizontal, 24)
                    .background(Color.zoneBackground)
                    // The button's top edge is 24 pt down. The line ends 16 pt above it.
                    .offset(y: -36)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
            }
            .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.24), value: pending)
            .task(id: pending?.id) {
                guard let item = pending else { return }
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled, pending == item { commit(item) }
            }
            .onDisappear {
                if let item = pending { commit(item) }
            }
    }
}
