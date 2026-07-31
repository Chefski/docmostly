import Foundation
import Observation

@MainActor
@Observable
final class DocumentSessionRegistry {
    @ObservationIgnored private let localPeer: DocumentLocalPersistencePeer
    @ObservationIgnored private let engineFactory: any NativeEditorCRDTDocumentEngineFactory
    @ObservationIgnored private let indexer: any DocumentUpdateIndexer
    @ObservationIgnored private let compactionPolicy: DocumentCompactionPolicy
    @ObservationIgnored private var sessions: [DocumentStoreKey: DocumentSession] = [:]
    @ObservationIgnored private var creationTasks: [DocumentStoreKey: Task<DocumentSession, any Error>] = [:]
    @ObservationIgnored private var generation: UInt = 0

    init(
        localPeer: DocumentLocalPersistencePeer,
        engineFactory: any NativeEditorCRDTDocumentEngineFactory,
        indexer: any DocumentUpdateIndexer = NoopDocumentUpdateIndexer(),
        compactionPolicy: DocumentCompactionPolicy = .production
    ) {
        self.localPeer = localPeer
        self.engineFactory = engineFactory
        self.indexer = indexer
        self.compactionPolicy = compactionPolicy
    }

    func session(
        for key: DocumentStoreKey,
        title: String,
        document: NativeEditorDocument
    ) async throws -> DocumentSession {
        if let session = sessions[key] {
            return session
        }
        if let creationTask = creationTasks[key] {
            let creationGeneration = generation
            let session = try await creationTask.value
            try Task.checkCancellation()
            guard generation == creationGeneration else {
                throw CancellationError()
            }
            return session
        }

        let creationGeneration = generation
        let creationTask = Task { @MainActor [localPeer, engineFactory, indexer, compactionPolicy] in
            let engine = try await engineFactory.makeDocumentEngine(
                pageID: key.pageID,
                title: title,
                document: document
            )
            let session = DocumentSession(
                key: key,
                kernel: NativeEditorDocumentKernel(documentEngine: engine),
                localPeer: localPeer,
                indexer: indexer,
                compactionPolicy: compactionPolicy
            )
            try await session.open(title: title)
            return session
        }
        creationTasks[key] = creationTask

        do {
            let session = try await creationTask.value
            guard generation == creationGeneration else {
                throw CancellationError()
            }
            sessions[key] = session
            creationTasks[key] = nil
            try Task.checkCancellation()
            return session
        } catch {
            if generation == creationGeneration {
                creationTasks[key] = nil
            }
            throw error
        }
    }

    func existingSession(for key: DocumentStoreKey) -> DocumentSession? {
        sessions[key]
    }

    func removeAll() {
        generation &+= 1
        for task in creationTasks.values {
            task.cancel()
        }
        creationTasks.removeAll()
        sessions.removeAll()
    }
}
