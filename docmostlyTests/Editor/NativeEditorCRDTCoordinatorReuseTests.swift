import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTCoordinatorReuseTests {
    @Test func viewModelReusesCRDTCoordinatorAcrossCollaborationSessions() async throws {
        let engine = CoordinatorReuseCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        let firstDriver = try #require(viewModel.collaborationSession().syncDriver)
        let secondDriver = try #require(viewModel.collaborationSession().syncDriver)
        let update = Data([23, 24])

        _ = await firstDriver.outboundFrame(forLocalUpdate: update)
        let echoFrames = try await secondDriver.outboundFrames(for: .update(update))

        #expect(echoFrames == [])
        #expect(engine.appliedRemoteUpdates == [])
    }
}

@MainActor
private final class CoordinatorReuseCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var appliedRemoteUpdates: [Data] = []

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        appliedRemoteUpdates.append(update)
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }
}
