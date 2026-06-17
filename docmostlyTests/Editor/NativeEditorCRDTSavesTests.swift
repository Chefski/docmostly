import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTSavesTests {
    @Test func crdtBackedSaveFlushesDocumentEngineWithoutRESTClient() async {
        let engine = SavingCRDTDocumentEngine()
        engine.saveResult = NativeEditorCRDTSaveResult(updatedAt: Date(timeIntervalSince1970: 20))
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Draft"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: " Page ",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.handleDocumentChanged()

        let didSave = await viewModel.save(appState: AppState())

        #expect(didSave == true)
        #expect(engine.flushRequests.count == 1)
        #expect(engine.flushRequests.first?.title == "Page")
        #expect(engine.flushRequests.first?.document == viewModel.document)
        #expect(viewModel.title == "Page")
        #expect(viewModel.lastSavedTitle == "Page")
        #expect(viewModel.lastSavedDocument == viewModel.document)
        #expect(viewModel.lastRemoteUpdatedAt == Date(timeIntervalSince1970: 20))
        #expect(viewModel.isDirty == false)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test func crdtBackedSavePreservesDirtyStateWhenFlushFails() async {
        let engine = SavingCRDTDocumentEngine()
        engine.error = APIError.connectionFailed("CRDT socket is disconnected.")
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Draft"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.handleDocumentChanged()

        let didSave = await viewModel.save(appState: AppState())

        #expect(didSave == false)
        #expect(viewModel.isDirty == true)
        #expect(viewModel.isSaving == false)
        #expect(
            viewModel.saveErrorMessage ==
                APIError.connectionFailed("CRDT socket is disconnected.").localizedDescription
        )
    }
}

@MainActor
private final class SavingCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    struct FlushRequest {
        let title: String
        let document: NativeEditorDocument
    }

    var flushRequests: [FlushRequest] = []
    var saveResult = NativeEditorCRDTSaveResult()
    var error: (any Error)?

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        flushRequests.append(FlushRequest(title: title, document: document))
        if let error {
            throw error
        }
        return saveResult
    }
}
