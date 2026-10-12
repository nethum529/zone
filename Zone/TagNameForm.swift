import SwiftUI

// The step after a new tag scan: give the tag a name, so it is easy to find later.
struct TagNameForm: View {
    let save: (String) -> Void
    let done: () -> Void
    @State private var name: String

    init(name: String?, save: @escaping (String) -> Void, done: @escaping () -> Void) {
        self.save = save
        self.done = done
        _name = State(initialValue: name ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZoneTitle("Name this tag")
            Text("Where does it live? For example Desk or Keychain.")
                .font(.zone(.body))
                .foregroundStyle(Color.zoneMute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Field(name: $name, label: "Name", placeholder: "Desk", focusOnAppear: true, onSubmit: saveAndClose)
                .padding(.horizontal, 24)
                .padding(.top, 12)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom) {
            Button("Save", action: saveAndClose)
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
    }

    private func saveAndClose() {
        save(name)
        done()
    }

    struct Field: View {
        @Binding var name: String
        let label: String
        let placeholder: String
        var focusOnAppear = false
        var onSubmit: (() -> Void)?
        @FocusState private var editing: Bool

        var body: some View {
            HStack(spacing: 16) {
                Text(label).foregroundStyle(Color.zoneMute)
                TextField(placeholder, text: $name)
                    .textFieldStyle(.plain)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)
                    .focused($editing)
                    .submitLabel(.done)
                    .onSubmit { editing = false; onSubmit?() }
                    .accessibilityLabel("Tag name")
            }
            .font(.zone(size: 17))
            .frame(height: 52)
            .contentShape(.rect)
            .onTapGesture { editing = true }
            .onAppear { if focusOnAppear { editing = true } }
        }
    }
}
