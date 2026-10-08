#if DEBUG && targetEnvironment(simulator)
import Observation
import SwiftUI

// Lets simulator tests choose a tag for each scan.
@MainActor
@Observable
final class SimulatedTagScan {
    static let backupID = "SIMULATED-BACKUP-TAG"
    static let otherID = "SIMULATED-OTHER-TAG"
    var prompt: String?
    private var continuation: CheckedContinuation<String?, Never>?

    func scan(prompt: String) async -> String? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.prompt = prompt
        }
    }

    func finish(_ id: String?) {
        let pending = continuation
        continuation = nil
        prompt = nil
        pending?.resume(returning: id)
    }
}

struct SimulatedTagScanPresenter: ViewModifier {
    let scan: SimulatedTagScan

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Choose a test tag", isPresented: Binding(
                get: { scan.prompt != nil },
                set: { if !$0 { scan.finish(nil) } }
            ), titleVisibility: .visible) {
                Button("Main test tag") { scan.finish(TagReader.simulatedTagID) }
                Button("Backup test tag") { scan.finish(SimulatedTagScan.backupID) }
                Button("Other test tag") { scan.finish(SimulatedTagScan.otherID) }
                Button("Cancel", role: .cancel) { scan.finish(nil) }
            } message: {
                Text(scan.prompt ?? "")
            }
            .onDisappear { scan.finish(nil) }
    }
}
#endif
