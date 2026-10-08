import SwiftUI

struct ZoneTagsView: View {
    let tags: ZoneTags
    @Environment(\.dismiss) private var dismiss
    @State private var action: TagChange?
    // true opens the backup tag page, false the main tag page.
    @State private var path: [Bool] = []

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ZoneTitle("Zone tags")
                ScrollView {
                    VStack(spacing: 0) {
                        tagRow(backup: false)
                        tagRow(backup: true)
                    }
                    .font(.system(size: 17))
                    .buttonStyle(ZoneRowStyle())
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .background(Color.zoneBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Bool.self) { TagPage(tags: tags, backup: $0, action: $action) }
        }
        .tint(Color.zoneBone)
        .foregroundStyle(Color.zoneInk)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .sheet(item: $action) { TagChangeView(action: $0, tags: tags) }
        .onChange(of: tags.backupID) {
            // The backup tag page has nothing to show once the tag is removed.
            if tags.backupID == nil { path.removeAll { $0 } }
        }
    }

    // A saved tag shows its name and opens its page. A missing tag shows Add.
    private func tagRow(backup: Bool) -> some View {
        let id = backup ? tags.backupID : tags.mainID
        let name = backup ? tags.backupName : tags.mainName
        let title = backup ? "Backup tag" : "Main tag"
        return Button {
            if id == nil { action = backup ? .addBackup : .addMain } else { path.append(backup) }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .foregroundStyle(Color.zoneMute)
                    .layoutPriority(1)
                Spacer()
                Text(id == nil ? "Add" : name ?? "Saved")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                ZoneCaret().padding(.trailing, -4)
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .disabled(backup && id == nil && tags.mainID == nil)
        .accessibilityLabel(id == nil ? (backup ? TagChange.addBackup : .addMain).title : "\(title), \(name ?? "no name")")
    }
}

// One saved tag: its name, replace, and remove for the backup tag.
private struct TagPage: View {
    let tags: ZoneTags
    let backup: Bool
    @Binding var action: TagChange?
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        let name = backup ? tags.backupName : tags.mainName
        VStack(spacing: 0) {
            ZoneTitle(name ?? (backup ? "Backup tag" : "Main tag"))
            ScrollView {
                VStack(spacing: 0) {
                    Button {
                        newName = name ?? ""
                        naming = true
                    } label: {
                        ZoneRow("Name", value: name ?? "None")
                    }
                    VStack(spacing: 0) {
                        Button { action = backup ? .replaceBackup : .replaceMain } label: {
                            actionRow("Replace tag")
                        }
                        if backup {
                            Button(role: .destructive) { action = .removeBackup } label: {
                                actionRow("Remove backup tag")
                            }
                        }
                    }
                    .padding(.top, 24)
                }
                .font(.system(size: 17))
                .buttonStyle(ZoneRowStyle())
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.zoneBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.zoneBackground, for: .navigationBar)
        .alert("Name this tag", isPresented: $naming) {
            TextField("Desk, Keychain", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { tags.setName(newName, backup: backup) }
        }
    }

    private func actionRow(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)
            .contentShape(.rect)
    }
}

enum TagChange: String, Identifiable {
    case addMain, replaceMain, addBackup, replaceBackup, removeBackup

    var id: Self { self }

    var title: String {
        switch self {
        case .addMain: "Add main tag"
        case .replaceMain: "Replace main tag"
        case .addBackup: "Add backup tag"
        case .replaceBackup: "Replace backup tag"
        case .removeBackup: "Remove backup tag"
        }
    }
}
