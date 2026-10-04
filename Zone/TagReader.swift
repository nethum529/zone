import CoreNFC
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
        return try await withCheckedThrowingContinuation { continuation in
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
        session.connect(to: tag) { [weak self] error in
            if let error {
                session.invalidate(errorMessage: "Could not read the tag. Try again.")
                self?.finish(.failure(error))
                return
            }
            guard let id = Self.identifier(of: tag) else {
                session.invalidate(errorMessage: TagReaderError.unsupportedTag.localizedDescription)
                self?.finish(.failure(TagReaderError.unsupportedTag))
                return
            }
            session.alertMessage = "Tag read."
            session.invalidate()
            self?.finish(.success(id))
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
