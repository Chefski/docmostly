import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTLocalChangeTests {
    @Test func documentEditsNotifyCRDTEngineWithBeforeAndAfterSnapshots() async throws {
        let engine = LocalChangeCRDTDocumentEngine()
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Draft"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.resetEditingHistory()

        viewModel.document.blocks[0].text = AttributedString("Draft updated")
        viewModel.handleDocumentChanged()
        await viewModel.waitForPendingCRDTLocalChange()

        let change = try #require(engine.localChanges.first)
        #expect(engine.localChanges.count == 1)
        #expect(change.before.title == "Page")
        #expect(change.after.title == "Page")
        #expect(change.before.document.blocks.map { String($0.text.characters) } == ["Draft"])
        #expect(change.after.document.blocks.map { String($0.text.characters) } == ["Draft updated"])
    }

    @Test func undoDoesNotNotifyCRDTEngineAsANewLocalEdit() async {
        let engine = LocalChangeCRDTDocumentEngine()
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Draft"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.resetEditingHistory()

        viewModel.document.blocks[0].text = AttributedString("Draft updated")
        viewModel.handleDocumentChanged()
        await viewModel.waitForPendingCRDTLocalChange()
        viewModel.undo()
        await viewModel.waitForPendingCRDTLocalChange()

        #expect(engine.localChanges.count == 1)
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Draft"])
    }

    @Test func successiveDocumentEditsNotifyCRDTEngineInOrder() async {
        let engine = LocalChangeCRDTDocumentEngine()
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("One"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.resetEditingHistory()

        viewModel.document.blocks[0].text = AttributedString("Two")
        viewModel.handleDocumentChanged()
        viewModel.document.blocks[0].text = AttributedString("Three")
        viewModel.handleDocumentChanged()
        await viewModel.waitForPendingCRDTLocalChange()

        #expect(engine.localChanges.map { $0.after.document.blocks.map { String($0.text.characters) } } == [
            ["Two"],
            ["Three"]
        ])
    }
}

@MainActor
private final class LocalChangeCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var localChanges: [NativeEditorCRDTLocalChange] = []

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws {
        localChanges.append(change)
    }

    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }
}
