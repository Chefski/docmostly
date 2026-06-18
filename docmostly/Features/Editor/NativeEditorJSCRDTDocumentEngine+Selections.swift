import Foundation

extension NativeEditorJSCRDTDocumentEngine {
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws
        -> NativeEditorResolvedRemoteCursor? {
        let cursor = try optionalRuntimeResult(
            function: "resolveRemoteCursor",
            payload: RuntimeRemoteCursor(cursor: cursor),
            as: RuntimeResolvedRemoteCursor.self
        )

        return cursor?.nativeCursor
    }

    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor? {
        try optionalRuntimeResult(
            function: "encodeLocalAwarenessCursor",
            payload: RuntimeLocalTextSelection(selection: selection),
            as: NativeEditorAwarenessCursor.self
        )
    }

    func encodeInlineCommentSelection(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorYjsSelection? {
        try optionalRuntimeResult(
            function: "encodeInlineCommentSelection",
            payload: RuntimeLocalTextSelection(selection: selection),
            as: NativeEditorYjsSelection.self
        )
    }
}

private struct RuntimeRemoteCursor: Encodable {
    let id: String
    let name: String
    let colorName: String
    let cursor: RuntimeAwarenessCursor

    init(cursor: NativeEditorRemoteCursor) {
        id = cursor.id
        name = cursor.name
        colorName = cursor.colorName
        self.cursor = RuntimeAwarenessCursor(cursor: cursor.cursor)
    }
}

private struct RuntimeAwarenessCursor: Encodable {
    let anchor: NativeEditorYjsRelativePosition?
    let head: NativeEditorYjsRelativePosition?

    init(cursor: NativeEditorAwarenessCursor) {
        anchor = cursor.anchor
        head = cursor.head
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let anchor {
            try container.encode(anchor, forKey: .anchor)
        } else {
            try container.encodeNil(forKey: .anchor)
        }

        if let head {
            try container.encode(head, forKey: .head)
        } else {
            try container.encodeNil(forKey: .head)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case anchor
        case head
    }
}

private struct RuntimeLocalTextSelection: Encodable {
    let anchor: RuntimeTextPosition
    let head: RuntimeTextPosition

    init(selection: NativeEditorLocalTextSelection) {
        anchor = RuntimeTextPosition(position: selection.anchor)
        head = RuntimeTextPosition(position: selection.head)
    }
}

private struct RuntimeResolvedRemoteCursor: Decodable {
    let id: String
    let name: String
    let colorName: String
    let anchor: RuntimeTextPosition
    let head: RuntimeTextPosition

    var nativeCursor: NativeEditorResolvedRemoteCursor {
        NativeEditorResolvedRemoteCursor(
            id: id,
            name: name,
            colorName: colorName,
            anchor: anchor.nativePosition,
            head: head.nativePosition
        )
    }
}

private struct RuntimeTextPosition: Codable {
    let blockIndex: Int
    let characterOffset: Int

    var nativePosition: NativeEditorRemoteTextPosition {
        NativeEditorRemoteTextPosition(blockIndex: blockIndex, characterOffset: characterOffset)
    }

    init(blockIndex: Int, characterOffset: Int) {
        self.blockIndex = blockIndex
        self.characterOffset = characterOffset
    }

    init(position: NativeEditorRemoteTextPosition) {
        blockIndex = position.blockIndex
        characterOffset = position.characterOffset
    }
}
