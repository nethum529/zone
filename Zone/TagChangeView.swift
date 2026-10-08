import SwiftUI

struct TagChangeView: View {
    let action: TagChange
    let tags: ZoneTags
    @Environment(\.dismiss) private var dismiss
    @State private var scanner = TagScanner()
    @State private var phase: Phase
    @State private var verifiedID: String?
    @State private var scanning = false

    private enum Phase { case verify, change, name }

    init(action: TagChange, tags: ZoneTags) {
        self.action = action
        self.tags = tags
        _phase = State(initialValue: tags.requiresVerification ? .verify : .change)
    }

    var body: some View {
        NavigationStack {
            if phase == .name {
                TagNameForm(tags: tags, backup: action == .addBackup || action == .replaceBackup) { dismiss() }
                    .toolbarBackground(Color.zoneBackground, for: .navigationBar)
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                scanPage
            }
        }
        .fontDesign(.rounded)
        .tint(Color.zoneBone)
        .preferredColorScheme(.dark)
        .tagScanAlert(scanner)
        .task(id: scanning) {
            guard scanning else { return }
            await scanOrRemove()
            scanning = false
        }
    }

    private var scanPage: some View {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ZoneTitle(title)
                        Text(detail)
                            .font(.body)
                            .foregroundStyle(Color.zoneMute)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                        Spacer(minLength: 24)
                    }
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                scanButton
                    .buttonStyle(ZoneButtonStyle())
                    .disabled(scanning)
                    .accessibilityIdentifier("tag-change-primary")
                    .padding(24)
                    .background(Color.zoneBackground)
            }
            .background(Color.zoneBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .toolbarBackground(Color.zoneBackground, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch phase {
        case .verify: "Scan a saved tag"
        case .change, .name: action.title
        }
    }

    private var detail: String {
        switch phase {
        case .verify:
            "Use your main or backup tag to allow this change."
        case .change, .name:
            action == .removeBackup
                ? "Your main tag will still work."
                : "Hold your iPhone near the new tag."
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .verify: "Scan"
        case .change, .name: action == .removeBackup ? "Remove" : "Scan"
        }
    }

    private var scanButton: some View {
        Button(buttonTitle) { scanning = true }
    }

    private func scanOrRemove() async {
        if phase == .verify {
            guard let id = await scanner.scan(prompt: "Scan a saved tag to allow this change."),
                  !Task.isCancelled else { return }
            guard tags.contains(id) else {
                scanner.errorMessage = "This tag is not saved. Use your main or backup tag."
                return
            }
            verifiedID = id
            phase = .change
            return
        }

        do {
            if action == .removeBackup {
                try tags.removeBackup(verifiedBy: verifiedID)
            } else {
                guard let id = await scanner.scan(prompt: "Hold your iPhone near the new tag."),
                      !Task.isCancelled else { return }
                switch action {
                case .addMain, .replaceMain: try tags.setMain(id, verifiedBy: verifiedID)
                case .addBackup, .replaceBackup: try tags.setBackup(id, verifiedBy: verifiedID)
                case .removeBackup: break
                }
            }
            verifiedID = nil
            // A new tag gets a name next. A removed tag has nothing to name.
            if action == .removeBackup { dismiss() } else { phase = .name }
        } catch {
            if error as? ZoneTagError == .verificationRequired {
                verifiedID = nil
                phase = .verify
            }
            scanner.errorMessage = error.localizedDescription
        }
    }
}
