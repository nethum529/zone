import FamilyControls
import SwiftUI

// The list of profiles. Opens from Settings as a sheet.
// Tap a row to open that profile. The check shows the profile in use.
struct ProfilesView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: [ZoneProfile.ID] = []
    @State private var adding = false
    @State private var newName = ""
    // The row that shows Delete now.
    @State private var swiped: ZoneProfile.ID?
    // Deleted by swipe but still kept until the undo line hides.
    @State private var pending: ZoneProfile?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ZoneTitle("Profiles")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visible) { profile in
                            profileRow(profile)
                                .padding(.horizontal, 24)
                                .swipeToDelete(profile.id, open: $swiped, enabled: canSwipeDelete(profile.id)) {
                                    swipeDelete(profile)
                                }
                        }
                    }
                }
                .contentMargins(.top, 24, for: .scrollContent)
                .onScrollPhaseChange { _, phase in
                    if phase != .idle { swiped = nil }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add profile") {
                    if let pending { commit(pending) }
                    newName = ""
                    adding = true
                }
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .undoLine($pending, text: { "\($0.name) deleted" }, commit: commit)
            }
            .profilePage()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .navigationDestination(for: ZoneProfile.ID.self) { ProfileView(id: $0) }
            .alert("New profile", isPresented: $adding) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    if let id = store.profiles.add(named: newName) { path.append(id) }
                }
                .disabled(isBlank(newName))
            }
        }
        .tint(Color.zoneBone)
        .foregroundStyle(Color.zoneInk)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .presentationBackground(Color.zoneBackground)
    }

    private func profileRow(_ profile: ZoneProfile) -> some View {
        let current = store.profiles.currentID == profile.id
        // With one profile there is nothing to choose, so no check.
        let checked = current && visible.count > 1
        return Button { path.append(profile.id) } label: {
            HStack(spacing: 6) {
                Text(profile.name)
                    .lineLimit(1)
                    .swipeLabel()
                Spacer()
                Image("check")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .opacity(checked ? 1 : 0)
                    .swipeValue()
                ZoneCaret()
                    .padding(.trailing, -4)
                    .swipeValue()
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .accessibilityLabel(profile.name)
        .accessibilityAddTraits(current ? .isSelected : [])
        .font(.system(size: 17))
        .buttonStyle(ZoneRowStyle())
    }

    // The profiles on screen. One that waits for its undo line is already gone.
    private var visible: [ZoneProfile] {
        store.profiles.all.filter { $0.id != pending?.id }
    }

    // Keep one profile on screen, and never delete the one that is locked now.
    private func canSwipeDelete(_ id: ZoneProfile.ID) -> Bool {
        visible.count > 1 && store.canDeleteProfile(id)
    }

    private func swipeDelete(_ profile: ZoneProfile) {
        if let pending { commit(pending) }
        withAnimation(.smooth(duration: 0.34)) {
            swiped = nil
            pending = profile
        }
    }

    // The undo line hid, so the delete is final.
    private func commit(_ profile: ZoneProfile) {
        if store.canDeleteProfile(profile.id) { store.profiles.delete(profile.id) }
        pending = nil
    }
}

// One profile: its apps, its name, and delete.
private struct ProfileView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: ZoneProfile.ID
    // The last known profile, so the page stays drawn while it slides away after a delete.
    @State private var last: ZoneProfile?
    @State private var picking = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var confirmingDelete = false

    var body: some View {
        let profile = store.profiles.profile(id) ?? last
        // The profile that is locked now cannot lose apps or be deleted.
        let inUse = store.isLocked && store.profiles.currentID == id
        let current = store.profiles.currentID == id
        VStack(spacing: 0) {
            ZoneTitle(profile?.name ?? "")
            ScrollView {
                VStack(spacing: 0) {
                    Button { picking = true } label: {
                        ZoneRow("Blocked apps", value: appsText(profile?.selection ?? FamilyActivitySelection()))
                    }
                    .disabled(inUse)
                    VStack(spacing: 0) {
                        if !current {
                            // While locked, the profile in use cannot change.
                            Button {
                                withAnimation(.smooth(duration: 0.3)) { store.profiles.choose(id) }
                                dismiss()
                            } label: {
                                actionRow("Use this profile")
                            }
                            .disabled(store.isLocked)
                        }
                        Button {
                            newName = profile?.name ?? ""
                            renaming = true
                        } label: {
                            actionRow("Rename")
                        }
                        Button { confirmingDelete = true } label: {
                            actionRow("Delete profile")
                        }
                        .disabled(!store.canDeleteProfile(id))
                    }
                    .padding(.top, 24)
                }
                .font(.system(size: 17))
                .buttonStyle(ZoneRowStyle())
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .profilePage()
        .onAppear { last = store.profiles.profile(id) }
        .onChange(of: store.profiles.profile(id)) { _, new in
            if let new { last = new }
        }
        .familyActivityPicker(isPresented: $picking, selection: selection)
        .alert("Rename profile", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { store.profiles.rename(id, to: newName) }
                .disabled(isBlank(newName))
        }
        .confirmationDialog("Delete \(profile?.name ?? "")?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete profile", role: .destructive) {
                dismiss()
                store.profiles.delete(id)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // A plain action row, like Remove backup tag in Zone tags.
    private func actionRow(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)
            .contentShape(.rect)
    }

    private var selection: Binding<FamilyActivitySelection> {
        Binding {
            store.profiles.profile(id)?.selection ?? FamilyActivitySelection()
        } set: {
            store.profiles.setSelection($0, for: id)
        }
    }
}

private extension ZoneStore {
    // Keep at least one profile, and never delete the one that is locked now.
    func canDeleteProfile(_ id: ZoneProfile.ID) -> Bool {
        profiles.canDelete && !(isLocked && profiles.currentID == id)
    }
}

private extension View {
    // Both pages put the title in the same place, under a plain bar like Zone tags.
    func profilePage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.zoneBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
    }
}

// "None", "1 app" or "3 apps".
func appsText(_ selection: FamilyActivitySelection) -> String {
    let count = selection.applicationTokens.count
        + selection.categoryTokens.count
        + selection.webDomainTokens.count
    return count == 0 ? "None" : "\(count) app\(count == 1 ? "" : "s")"
}

private func isBlank(_ name: String) -> Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
