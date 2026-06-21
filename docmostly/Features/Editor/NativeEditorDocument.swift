import Foundation

nonisolated struct NativeEditorDocument: Equatable {
    var blocks: [NativeEditorBlock]

    init(blocks: [NativeEditorBlock] = [Self.emptyBlock()]) {
        self.blocks = blocks.isEmpty ? [Self.emptyBlock()] : blocks
    }

    init(proseMirrorJSONData data: Data) throws {
        let document = try JSONDecoder().decode(ProseMirrorDocument.self, from: data)
        try document.validateNativeEditorBudget()
        self.init(proseMirrorDocument: document)
    }

    init(proseMirrorDocument: ProseMirrorDocument) {
        guard proseMirrorDocument.isWithinNativeEditorBudget else {
            blocks = [Self.emptyBlock()]
            return
        }

        let decodedBlocks = proseMirrorDocument.content.flatMap(Self.blocks(from:))
        blocks = decodedBlocks.isEmpty ? [Self.emptyBlock()] : decodedBlocks
    }

    var proseMirrorDocument: ProseMirrorDocument {
        ProseMirrorDocument(content: Self.nodes(from: blocks))
    }

    func proseMirrorJSONData() throws -> Data {
        try JSONEncoder().encode(proseMirrorDocument)
    }

    static func emptyBlock() -> NativeEditorBlock {
        NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
    }
}
