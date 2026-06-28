import Foundation

nonisolated extension ProseMirrorDocument {
    func replacingCommentID(
        _ localID: String,
        with serverID: String
    ) -> (document: ProseMirrorDocument, didReplace: Bool) {
        let replacement = content.replacingCommentID(localID, with: serverID)
        guard replacement.didReplace else {
            return (self, false)
        }
        return (ProseMirrorDocument(type: type, content: replacement.nodes), true)
    }
}

private extension [ProseMirrorNode] {
    func replacingCommentID(_ localID: String, with serverID: String) -> (nodes: [ProseMirrorNode], didReplace: Bool) {
        var didReplace = false
        let nodes = map { node in
            let replacement = node.replacingCommentID(localID, with: serverID)
            didReplace = didReplace || replacement.didReplace
            return replacement.node
        }
        return (nodes, didReplace)
    }
}

private extension ProseMirrorNode {
    func replacingCommentID(_ localID: String, with serverID: String) -> (node: ProseMirrorNode, didReplace: Bool) {
        var copy = self
        var didReplace = false

        if let marks {
            let replacement = marks.replacingCommentID(localID, with: serverID)
            copy.marks = replacement.marks
            didReplace = didReplace || replacement.didReplace
        }

        if let content {
            let replacement = content.replacingCommentID(localID, with: serverID)
            copy.content = replacement.nodes
            didReplace = didReplace || replacement.didReplace
        }

        return (copy, didReplace)
    }
}

private extension [ProseMirrorMark] {
    func replacingCommentID(_ localID: String, with serverID: String) -> (marks: [ProseMirrorMark], didReplace: Bool) {
        var didReplace = false
        let marks = map { mark in
            var copy = mark
            guard copy.type == "comment", copy.attrs?["commentId"] == .string(localID) else {
                return copy
            }

            copy.attrs?["commentId"] = .string(serverID)
            didReplace = true
            return copy
        }
        return (marks, didReplace)
    }
}
