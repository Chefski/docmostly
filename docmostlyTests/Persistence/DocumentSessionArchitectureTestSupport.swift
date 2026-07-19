import Foundation
@testable import docmostly

@MainActor
final class SessionTestDocumentEngine: NativeEditorCRDTDocumentEngine {
    let requiresInitialRemoteSnapshot = true
    private(set) var appliedUpdates: [Data] = []
    private var localSequence = 0

    func encodeStateVector() async throws -> Data {
        Data([0])
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        _ = stateVector
        return try await encodeDocumentState()
    }

    func encodeDocumentState() async throws -> Data {
        Data("state-\(localSequence)-\(appliedUpdates.count)".utf8)
    }

    func validateUpdate(_ update: Data) async throws {
        let value = String(bytes: update, encoding: .utf8) ?? ""
        guard update.isEmpty == false, value.hasPrefix("corrupt") == false else {
            throw DocumentSessionTestError.corrupt
        }
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        _ = try await applyRemoteUpdateCapturingSnapshot(update)
    }

    func applyRemoteUpdateCapturingSnapshot(
        _ update: Data
    ) async throws -> NativeEditorCRDTDocumentSnapshot? {
        try await validateUpdate(update)
        if appliedUpdates.contains(update) == false {
            appliedUpdates.append(update)
        }
        return NativeEditorCRDTDocumentSnapshot(title: "Page", document: NativeEditorDocument())
    }

    func currentDocumentSnapshot() async throws -> NativeEditorCRDTDocumentSnapshot? {
        NativeEditorCRDTDocumentSnapshot(title: "Page", document: NativeEditorDocument())
    }

    func integrateLocalChangeForCommit(_ change: NativeEditorCRDTLocalChange) async throws -> [Data] {
        _ = change
        localSequence += 1
        return [Data("local-\(localSequence)".utf8)]
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        let committed = try await flushPendingLocalChangesForCommit(title: title, document: document)
        return committed.result
    }

    func flushPendingLocalChangesForCommit(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTCommittedSave {
        _ = document
        localSequence += 1
        let update = Data("local-\(localSequence)".utf8)
        return NativeEditorCRDTCommittedSave(
            result: NativeEditorCRDTSaveResult(
                title: title,
                documentStateUpdate: try await encodeDocumentState()
            ),
            updates: [update]
        )
    }
}

@MainActor
final class SessionTestDocumentEngineFactory: NativeEditorCRDTDocumentEngineFactory {
    private(set) var engines: [SessionTestDocumentEngine] = []

    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine {
        _ = pageID
        _ = title
        _ = document
        let engine = SessionTestDocumentEngine()
        engines.append(engine)
        return engine
    }
}

actor RecordingDocumentUpdateIndexer: DocumentUpdateIndexer {
    private(set) var count = 0

    func documentUpdateCommitted(_ update: CommittedDocumentUpdate) {
        _ = update
        count += 1
    }
}

actor DocumentSessionTestEventLog {
    private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }
}

struct FailingDocumentCompactionFaultInjector: DocumentCompactionFaultInjector {
    func beforeCompactionCommit() async throws {
        throw DocumentSessionTestError.compactionCrash
    }
}

enum DocumentSessionTestError: Error {
    case corrupt
    case compactionCrash
}
