import Foundation

nonisolated extension ProseMirrorDocument {
    func isCollaborationEquivalent(to other: ProseMirrorDocument) -> Bool {
        collaborationNormalized == other.collaborationNormalized
    }

    private var collaborationNormalized: ProseMirrorDocument {
        ProseMirrorDocument(
            type: type,
            content: content.map(\.collaborationNormalized)
        )
    }
}

private nonisolated extension ProseMirrorNode {
    var collaborationNormalized: ProseMirrorNode {
        var normalized = self
        normalized.content = content?.map(\.collaborationNormalized)

        if type == "paragraph" || type == "heading" {
            var normalizedAttributes = attrs ?? [:]
            normalizedAttributes.removeValue(forKey: "id")
            normalized.attrs = normalizedAttributes.isEmpty ? nil : normalizedAttributes
        }

        return normalized
    }
}
