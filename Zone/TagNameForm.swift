import SwiftUI

// The step after a new tag scan: give the tag a name, so it is easy to find later.
struct TagNameForm: View {
    let tags: ZoneTags
    let backup: Bool
    let done: () -> Void
    @State private var name: String
    @FocusState private var editing: Bool

    init(tags: ZoneTags, backup: Bool, done: @escaping () -> Void) {
        self.tags = tags
        self.backup = backup
        self.done = done
        _name = State(initialValue: (backup ? tags.backupName : tags.mainName) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZoneTitle("Name this tag")
            Text("Where does it live? For example Desk or Keychain.")
                .font(.body)
                .foregroundStyle(Color.zoneMute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            HStack(spacing: 16) {
                Text("Name").foregroundStyle(Color.zoneMute)
                TextField("Desk", text: $name)
                    .textFieldStyle(.plain)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
                    .focused($editing)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .accessibilityLabel("Tag name")
            }
            .font(.system(size: 17))
            .frame(height: 52)
            .contentShape(.rect)
            .onTapGesture { editing = true }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            Button("Save", action: save)
                .buttonStyle(ZoneButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(24)
                .background(Color.zoneBackground)
        }
        .background(Color.zoneBackground)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip", action: done)
            }
        }
        .onAppear { editing = true }
    }

    private func save() {
        tags.setName(name, backup: backup)
        done()
    }
}
