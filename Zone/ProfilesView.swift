import FamilyControls
import SwiftUI

// The list of profiles. Opens from Settings as a sheet.
struct ProfilesView: View {
    @Environment(ZoneStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: [ZoneProfile.ID] = []
    @State private var adding = false
    @State private var newName = ""

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ZoneTitle("Profiles")
                Form {
                    Section {
                        ForEach(store.profiles.all) { profile in
                            Button { path.append(profile.id) } label: {
                                HStack {
                                    Text(profile.name)
                                        .foregroundStyle(Color.zoneInk)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(appsText(profile.selection))
                                        .foregroundStyle(Color.zoneMute)
                                    ZoneCaret()
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.zoneCard)
                }
                .scrollContentBackground(.hidden)
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add profile") {
                    newName = ""
                    adding = true
                }
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
            }
            .profilePage()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
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
        .tint(Color.zoneInk)
        .presentationBackground(Color.zoneBackground)
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
        VStack(spacing: 0) {
            ZoneTitle(profile?.name ?? "")
            Form {
                Section {
                    Button { picking = true } label: {
                        ZoneRow("prohibit-fill", "Blocked apps", value: appsText(profile?.selection ?? FamilyActivitySelection()))
                    }
                    .disabled(inUse)
                }
                .listRowBackground(Color.zoneCard)
                Section {
                    Button("Rename") {
                        newName = profile?.name ?? ""
                        renaming = true
                    }
                    .foregroundStyle(Color.zoneInk)
                    // The app sets ink on all text, so set the destructive red again here.
                    Button("Delete profile", role: .destructive) { confirmingDelete = true }
                        .foregroundStyle(.red)
                        .disabled(inUse || !store.profiles.canDelete)
                }
                .listRowBackground(Color.zoneCard)
            }
            .scrollContentBackground(.hidden)
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

    private var selection: Binding<FamilyActivitySelection> {
        Binding {
            store.profiles.profile(id)?.selection ?? FamilyActivitySelection()
        } set: {
            store.profiles.setSelection($0, for: id)
        }
    }
}

private extension View {
    // Both pages put the title in the same place, under an empty bar.
    func profilePage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.zoneBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// "None", "1 app" or "3 apps", the same as the old Blocked apps row.
private func appsText(_ selection: FamilyActivitySelection) -> String {
    let count = selection.applicationTokens.count
        + selection.categoryTokens.count
        + selection.webDomainTokens.count
    return count == 0 ? "None" : "\(count) app\(count == 1 ? "" : "s")"
}

private func isBlank(_ name: String) -> Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
