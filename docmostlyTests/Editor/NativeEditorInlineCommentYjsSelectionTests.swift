import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeInlineCommentYjsTests {
    @Test func viewModelResolvesInlineCommentSelectionThroughCRDTEngine() async throws {
        let engine = InlineCommentSelectionCRDTDocumentEngine()
        let yjsSelection = NativeEditorYjsSelection(
            anchor: NativeEditorYjsSelectionPosition(
                type: NativeEditorYjsID(client: 1, clock: 10),
                targetName: nil,
                item: NativeEditorYjsID(client: 1, clock: 11),
                assoc: 0
            ),
            head: NativeEditorYjsSelectionPosition(
                type: NativeEditorYjsID(client: 1, clock: 12),
                targetName: nil,
                item: nil,
                assoc: -1
            )
        )
        engine.inlineCommentSelection = yjsSelection
        let text = AttributedString("Inline comment selection")
        let range = try #require(text.range(of: "comment"))
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: text,
            alignment: .left,
            selection: AttributedTextSelection(range: range)
        )
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [block])
        let context = NativeEditorInlineCommentContext(
            blockID: block.id,
            selectedText: "comment",
            selection: block.selection
        )

        let resolvedSelection = await viewModel.inlineCommentYjsSelection(for: context)

        #expect(resolvedSelection == yjsSelection)
        #expect(engine.inlineCommentSelectionRequests == [
            NativeEditorLocalTextSelection(
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 7),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 14)
            )
        ])
    }
}

@MainActor
private final class InlineCommentSelectionCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var inlineCommentSelection: NativeEditorYjsSelection?
    var inlineCommentSelectionRequests: [NativeEditorLocalTextSelection] = []

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
        NativeEditorCRDTSaveResult()
    }

    func encodeInlineCommentSelection(
        for selection: NativeEditorLocalTextSelection
    ) async throws -> NativeEditorYjsSelection? {
        inlineCommentSelectionRequests.append(selection)
        return inlineCommentSelection
    }
}
