import SwiftData
import Testing
@testable import docmostly

@MainActor
struct DocumentSessionRegistryTests {
    @Test func cancelledOwnerStillRegistersASuccessfullyCreatedSession() async throws {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let factory = SuspendingDocumentEngineFactory()
        let registry = DocumentSessionRegistry(
            localPeer: DocumentLocalPersistencePeer(modelContainer: container),
            engineFactory: factory
        )
        let key = DocumentStoreKey(
            serverBaseURL: "https://docs.example.com",
            userID: "user-1",
            workspaceID: "workspace-1",
            pageID: "page-1"
        )
        let owner = Task { @MainActor in
            try await registry.session(for: key, title: "Page", document: NativeEditorDocument())
        }
        await factory.waitUntilStarted()

        owner.cancel()
        factory.resume()
        await #expect(throws: CancellationError.self) {
            try await owner.value
        }
        let reused = try await registry.session(for: key, title: "Page", document: NativeEditorDocument())

        #expect(registry.existingSession(for: key) === reused)
        #expect(factory.creationCount == 1)
    }
}

@MainActor
private final class SuspendingDocumentEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    private(set) var creationCount = 0
    private var hasStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var creationContinuation: CheckedContinuation<Void, Never>?

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        _ = pageID
        _ = title
        _ = document
        creationCount += 1
        hasStarted = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters = []
        await withCheckedContinuation { continuation in
            creationContinuation = continuation
        }
        return SessionTestDocumentEngine()
    }

    func waitUntilStarted() async {
        guard hasStarted == false else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func resume() {
        creationContinuation?.resume()
        creationContinuation = nil
    }
}
