import Foundation

nonisolated extension NativeEditorDocument {
    static func addDocmostNodeIDIfNeeded(
        type: String,
        block: NativeEditorBlock,
        attrs: inout [String: ProseMirrorJSONValue]
    ) {
        guard attrs["id"] == nil, type == "paragraph" || type == "heading" else { return }
        attrs["id"] = .string(docmostNodeID(from: block.id))
    }

    private static func docmostNodeID(from id: UUID) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.uuidString.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }

        var value = hash
        var characters: [Character] = []
        characters.reserveCapacity(Self.docmostNodeIDLength)

        // Docmost web generates 12 lowercase-letter IDs; deriving from the local UUID keeps native saves stable.
        for _ in 0..<Self.docmostNodeIDLength {
            value = value &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let index = Int(value % UInt64(Self.docmostNodeIDAlphabet.count))
            characters.append(Self.docmostNodeIDAlphabet[index])
        }

        return String(characters)
    }

    private static let docmostNodeIDAlphabet = Array("abcdefghijklmnopqrstuvwxyz")
    private static let docmostNodeIDLength = 12
}
