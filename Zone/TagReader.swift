@preconcurrency import CoreNFC
import Foundation

enum TagReaderError: LocalizedError {
    case unavailable
    case unsupportedTag

    var errorDescription: String? {
        switch self {
        case .unavailable: "This device cannot read NFC tags."
        case .unsupportedTag: "Zone cannot read this kind of tag."
        }
    }
}

// Reads the hardware ID of one NFC tag.
// The ID is fixed in the tag chip, so a copy of the sticker does not unlock Zone.
final class TagReader: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    // In debug builds without NFC (the simulator), a scan returns this fake ID.
    static let simulatedTagID = "SIMULATED-TAG"

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?

    @MainActor
    func scan(prompt: String) async throws -> String {
        guard NFCTagReaderSession.readingAvailable else {
            #if DEBUG
            return Self.simulatedTagID
            #else
            throw TagReaderError.unavailable
            #endif
        }
        // Right after a scan sheet closes, the reader is busy for a moment.
        // A new scan then fails at once with "System resource unavailable", so wait and try again.
        var attempt = 1
        while true {
            do {
                return try await read(prompt: prompt)
            } catch let error as NFCReaderError where error.code == .readerSessionInvalidationErrorSystemIsBusy && attempt < 5 {
                attempt += 1
                try await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    @MainActor
    private func read(prompt: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: nil)
            session?.alertMessage = prompt
            self.session = session
            session?.begin()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        finish(.failure(error))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }
        guard let id = Self.identifier(of: tag) else {
            session.invalidate(errorMessage: TagReaderError.unsupportedTag.localizedDescription)
            finish(.failure(TagReaderError.unsupportedTag))
            return
        }
        // The completion handler is Sendable, so it gets the session from self
        // and does not capture the session or the tag.
        session.connect(to: tag) { [weak self] error in
            guard let self, let session = self.session else { return }
            if let error {
                session.invalidate(errorMessage: "Could not read the tag. Try again.")
                self.finish(.failure(error))
                return
            }
            session.alertMessage = "Tag read."
            session.invalidate()
            self.finish(.success(id))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        session = nil
    }

    private static func identifier(of tag: NFCTag) -> String? {
        let data: Data
        switch tag {
        case .miFare(let t): data = t.identifier
        case .iso15693(let t): data = t.identifier
        case .iso7816(let t): data = t.identifier
        case .feliCa(let t): data = t.currentIDm
        @unknown default: return nil
        }
        return data.map { String(format: "%02X", $0) }.joined()
    }
}
