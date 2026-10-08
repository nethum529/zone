import SwiftUI

// The Home row that picks the profile to lock. Shown only when there are 2 or more profiles.
// While locked, it cannot change, and it shows the profile in use.
struct ProfileMenu: View {
    @Environment(ZoneStore.self) private var store

    var body: some View {
        let locked = store.isLocked
        Menu {
            Picker("Profile", selection: choice) {
                ForEach(store.profiles.all) { Text($0.name).tag($0.id) }
            }
        } label: {
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
                if !locked {
                    Image("caret-up-down")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(Color.zoneMute)
                        .transition(.opacity)
                }
            }
            .font(.system(size: 17))
            .frame(height: 44)
            .contentShape(.rect)
        }
        // Keep the same order as the Profiles list, wherever the menu opens.
        .menuOrder(.fixed)
        .disabled(locked)
        // A 44 pt tap target in a 30 pt row, like the other Home rows.
        .padding(.vertical, -7)
    }

    private var choice: Binding<ZoneProfile.ID> {
        Binding {
            store.profiles.currentID
        } set: { id in
            withAnimation(.smooth(duration: 0.3)) { store.profiles.choose(id) }
        }
    }
}
