import SwiftUI

// The Home row that picks the profile to lock. Shown only when there are 2 or more profiles.
// In the Zone the menu does not open. A tap shows why.
struct ProfileMenu: View {
    @Environment(ZoneStore.self) private var store
    @State private var lockedTaps = 0

    var body: some View {
        Group {
            if store.isZoned {
                Button { lockedTaps += 1 } label: { label }
                    .buttonStyle(.plain)
            } else {
                Menu {
                    Picker("Profile", selection: choice) {
                        ForEach(store.profiles.all) { Text($0.name).tag($0.id) }
                    }
                } label: {
                    label
                }
                // Keep the same order as the Profiles list, wherever the menu opens.
                .menuOrder(.fixed)
            }
        }
        // A 44 pt tap target in a 30 pt row, like the other Home rows.
        .padding(.vertical, -7)
        .profileLockedNote(taps: lockedTaps)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Text("Profile")
                .foregroundStyle(Color.zoneMute)
                .layoutPriority(1)
            Spacer()
            Text(store.profiles.current.name)
                .fontWeight(.semibold)
                .foregroundStyle(Color.zoneInk)
                .lineLimit(1)
                .contentTransition(.opacity)
            Image("caret-up-down")
                .resizable()
                .frame(width: 14, height: 14)
                .foregroundStyle(Color.zoneMute)
        }
        .font(.zone(size: 17))
        .frame(height: 44)
        .contentShape(.rect)
    }

    private var choice: Binding<ZoneProfile.ID> {
        Binding {
            store.profiles.currentID
        } set: { id in
            withAnimation(.smooth(duration: 0.3)) { store.chooseProfile(id) }
        }
    }
}

extension View {
    // Each new tap on a profile choice in the Zone shakes the row, plays an error haptic
    // and shows a line under the row for 3 seconds. With Reduce Motion the row does not shake.
    func profileLockedNote(taps: Int) -> some View {
        modifier(ProfileLockedNote(taps: taps))
    }
}

private struct ProfileLockedNote: ViewModifier {
    let taps: Int
    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let text = "Leave the Zone to change profile."

    func body(content: Content) -> some View {
        let size = reduceMotion ? 0.0 : 1.0
        return VStack(alignment: .leading, spacing: 0) {
            content
                .keyframeAnimator(initialValue: 0.0, trigger: taps) { row, x in
                    row.offset(x: x)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(-7 * size, duration: 0.08)
                        LinearKeyframe(6 * size, duration: 0.08)
                        LinearKeyframe(-4 * size, duration: 0.08)
                        LinearKeyframe(2 * size, duration: 0.08)
                        LinearKeyframe(0, duration: 0.08)
                    }
                }
            if isShown {
                Text(Self.text)
                    .font(.zone(size: 15))
                    .foregroundStyle(Color.zoneMute)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -4)))
            }
        }
        .sensoryFeedback(.error, trigger: taps)
        .task(id: taps) {
            guard taps > 0 else { return }
            AccessibilityNotification.Announcement(Self.text).post()
            withAnimation(.smooth(duration: 0.3)) { isShown = true }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.3)) { isShown = false }
        }
    }
}
