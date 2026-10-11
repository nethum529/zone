import SwiftUI

struct ZoneTagsView: View {
    let tags: ZoneTags
    @Environment(\.dismiss) private var dismiss
    @State private var action: TagChange?
    @State private var path: [ZoneTag.ID] = []
    // The row that shows Delete now.
    @State private var swiped: ZoneTag.ID?
    // Deleted by swipe but still kept until the undo line hides.
    @State private var pending: ZoneTag?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ZoneTitle("Zone tags")
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visible) { tag in
                            tagRow(tag)
                                .padding(.horizontal, 24)
                                .swipeToDelete(tag.id, open: $swiped, enabled: visible.count > 1) {
                                    swipeDelete(tag)
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
                Button("Add tag") {
                    if let pending { commit(pending) }
                    action = .add
                }
                .buttonStyle(ZoneButtonStyle())
                .padding(24)
                .undoLine($pending, text: { "\(tags.title($0.id)) deleted" }, commit: commit)
            }
            // Only while the list shows, not under a tag page or the add sheet.
            .swipeHint("tags", row: visible.count > 1 && path.isEmpty && action == nil ? visible.first?.id : nil)
            .background(Color.zoneBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ZoneTag.ID.self) { TagPage(tags: tags, id: $0, action: $action) }
        }
        .tint(Color.zoneBone)
        .foregroundStyle(Color.zoneInk)
        .font(.zone(.body))
        .preferredColorScheme(.dark)
        .sheet(item: $action) { TagChangeView(action: $0, tags: tags) }
        .onChange(of: tags.all) {
            // A deleted tag's page has nothing to show.
            path.removeAll { tags.tag($0) == nil }
        }
    }

    private func tagRow(_ tag: ZoneTag) -> some View {
        let title = tags.title(tag.id)
        return Button { path.append(tag.id) } label: {
            HStack(spacing: 6) {
                Text(title)
                    .lineLimit(1)
                    .swipeLabel()
                Spacer()
                ZoneCaret()
                    .padding(.trailing, -4)
                    .swipeValue()
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .accessibilityLabel(title)
        .font(.zone(size: 17))
        .buttonStyle(ZoneRowStyle())
    }

    // The tags on screen. One that waits for its undo line is already gone.
    private var visible: [ZoneTag] {
        tags.all.filter { $0.id != pending?.id }
    }

    // In the Zone, a delete needs a scan of a saved tag first, so it opens the scan sheet.
    private func swipeDelete(_ tag: ZoneTag) {
        if let pending { commit(pending) }
        if tags.requiresVerification {
            swiped = nil
            action = .delete(tag.id)
            return
        }
        withAnimation(.smooth(duration: 0.34)) {
            swiped = nil
            pending = tag
        }
    }

    // The undo line hid, so the delete is final. If the Zone started meanwhile, the tag stays.
    private func commit(_ tag: ZoneTag) {
        try? tags.delete(tag.id)
        withAnimation(.smooth(duration: 0.34)) { pending = nil }
    }
}

// One saved tag: its name, replace, and delete.
private struct TagPage: View {
    let tags: ZoneTags
    let id: ZoneTag.ID
    @Binding var action: TagChange?
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        let name = tags.tag(id)?.name
        VStack(spacing: 0) {
            ZoneTitle(tags.title(id))
            ScrollView {
                VStack(spacing: 0) {
                    Button {
                        newName = name ?? ""
                        naming = true
                    } label: {
                        ZoneRow("Name", value: name ?? "None")
                    }
                    VStack(spacing: 0) {
                        Button { action = .replace(id) } label: {
                            actionRow("Replace tag")
                        }
                        // The last tag stays, so Zone can always be left.
                        Button(role: .destructive) { action = .delete(id) } label: {
                            actionRow("Delete tag")
                        }
                        .disabled(tags.all.count < 2)
                    }
                    .padding(.top, 24)
                }
                .font(.zone(size: 17))
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
            Button("Save") { tags.rename(id, to: newName) }
        }
    }

    private func actionRow(_ title: String) -> some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 52)
            .contentShape(.rect)
    }
}

enum TagChange: Identifiable, Hashable {
    case add, replace(ZoneTag.ID), delete(ZoneTag.ID)

    var id: Self { self }

    var isDelete: Bool {
        if case .delete = self { true } else { false }
    }

    var title: String {
        switch self {
        case .add: "Add tag"
        case .replace: "Replace tag"
        case .delete: "Delete tag"
        }
    }
}
