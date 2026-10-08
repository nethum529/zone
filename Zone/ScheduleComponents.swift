import SwiftUI

// The plain label and value layout used by Settings.
struct ScheduleValueRow: View {
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 6) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).foregroundStyle(Color.zoneMute)
                    Text(value).fontWeight(.semibold)
                }
                Spacer(minLength: 0)
            } else {
                Text(title).foregroundStyle(Color.zoneMute)
                Spacer(minLength: 16)
                Text(value)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
            }
            ZoneCaret().padding(.trailing, -4)
        }
        .font(.body)
        .frame(minHeight: 52)
        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
        .contentShape(.rect)
    }
}

extension View {
    func schedulePage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.zoneBackground)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(.rounded)
            .foregroundStyle(Color.zoneInk)
            .tint(Color.zoneBone)
            .preferredColorScheme(.dark)
    }
}
