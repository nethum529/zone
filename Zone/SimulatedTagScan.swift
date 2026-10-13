#if DEBUG && targetEnvironment(simulator)
import CoreNFC
import Observation
import SwiftUI

// Lets simulator tests choose a tag for each scan.
@MainActor
@Observable
final class SimulatedTagScan {
    static let backupID = "SIMULATED-BACKUP-TAG"
    static let otherID = "SIMULATED-OTHER-TAG"
    static let randomID = "08A1B2C3"
    var prompt: String?
    private(set) var reads = 1
    private var continuation: CheckedContinuation<[String]?, any Error>?

    func scan(prompt: String, reads: Int) async throws -> [String]? {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.reads = reads
            self.prompt = prompt
        }
    }

    // Each read of the tag returns the same ID.
    func finish(_ id: String?) {
        finish(ids: id.map { Array(repeating: $0, count: reads) })
    }

    // Each read returns a new ID, like a card in random ID mode.
    func finishChanging() {
        finish(ids: (0..<reads).map { "SIMULATED-RANDOM-\($0)" })
    }

    private func finish(ids: [String]?) {
        let pending = continuation
        continuation = nil
        prompt = nil
        pending?.resume(returning: ids)
    }

    func fail(_ error: any Error = TagReaderError.unsupportedTag) {
        let pending = continuation
        continuation = nil
        prompt = nil
        pending?.resume(throwing: error)
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
                if scan.reads > 1 {
                    Button("Changing ID test tag") { scan.finishChanging() }
                    Button("Random ID test tag") { scan.finish(SimulatedTagScan.randomID) }
                }
                Button("Unreadable test tag") { scan.fail() }
                Button("Timed out test tag") {
                    scan.fail(NSError(domain: NFCErrorDomain, code: NFCReaderError.Code.readerSessionInvalidationErrorSessionTimeout.rawValue))
                }
                Button("Cancel", role: .cancel) { scan.finish(nil) }
            } message: {
                Text(scan.prompt ?? "")
            }
            .onDisappear { scan.finish(nil) }
    }
}
#endif
