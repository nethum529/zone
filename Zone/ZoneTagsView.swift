import SwiftUI

struct ZoneTagsView: View {
    let tags: ZoneTags
    @Environment(\.dismiss) private var dismiss
    @State private var action: TagChange?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoneTitle("Zone tags")
                ScrollView {
                    VStack(spacing: 0) {
                        tagRow("Main tag", id: tags.mainID,
                               action: tags.mainID == nil ? .addMain : .replaceMain)
                        tagRow("Backup tag", id: tags.backupID,
                               action: tags.backupID == nil ? .addBackup : .replaceBackup)

                        if tags.backupID != nil {
                            Button(role: .destructive) { action = .removeBackup } label: {
                                Text("Remove backup tag")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 52)
                                    .contentShape(.rect)
                            }
                            .padding(.top, 24)
                        }
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
        }
        .tint(Color.zoneBone)
        .foregroundStyle(Color.zoneInk)
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
        .sheet(item: $action) { TagChangeView(action: $0, tags: tags) }
    }

    private func tagRow(_ title: String, id: String?, action: TagChange) -> some View {
        Button { self.action = action } label: {
            HStack(spacing: 6) {
                Text(title)
                    .foregroundStyle(Color.zoneMute)
                    .layoutPriority(1)
                Spacer()
                Text(id == nil ? "Add" : "Replace")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                ZoneCaret().padding(.trailing, -4)
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .disabled(action == .addBackup && tags.mainID == nil)
        .accessibilityLabel(action.title)
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
