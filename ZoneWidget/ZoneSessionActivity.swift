import ActivityKit
import SwiftUI
import WidgetKit

// The Live Activity while in the Zone, on the Lock Screen and in the Dynamic Island.
struct ZoneSessionActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZoneActivityAttributes.self) { context in
            SessionSummary(since: context.attributes.since, timerSize: 48)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .activityBackgroundTint(Color.zoneBackground)
                .activitySystemActionForegroundColor(Color.zoneInk)
        } dynamicIsland: { context in
            let since = context.attributes.since
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZoneMark(size: 24, color: .zoneBone)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionSummary(since: since, timerSize: 40)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                ZoneMark(size: 18, color: .zoneBone)
            } compactTrailing: {
                SessionTimer(since: since)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.zoneInk)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 64, alignment: .trailing)
            } minimal: {
                ZoneMark(size: 18, color: .zoneBone)
            }
            .keylineTint(Color.zoneBone)
        }
    }
}

// The session time, then when it started.
private struct SessionSummary: View {
    let since: Date
    let timerSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SessionTimer(since: since)
                .font(.system(size: timerSize, weight: .bold, design: .rounded))
                .tracking(-1)
            Text("In the Zone since \(since.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Color.zoneMute)
        }
        .foregroundStyle(Color.zoneInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Counts up from the start of the session. iOS updates it without the app.
private struct SessionTimer: View {
    let since: Date

    var body: some View {
        Text(timerInterval: since...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .lineLimit(1)
    }
}

// The Latch mark. With no color it uses the system color, so the Lock Screen can tint it.
struct ZoneMark: View {
    let size: CGFloat
    var color: Color? = nil

    var body: some View {
        Image("zone-mark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color ?? .primary)
    }
}
