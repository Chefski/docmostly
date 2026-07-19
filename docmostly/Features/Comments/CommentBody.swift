import Foundation
import SwiftUI

nonisolated struct CommentBody: Hashable, Sendable {
    let document: ProseMirrorDocument

    init(document: ProseMirrorDocument) {
        self.document = document
    }

    init(plainText: String) {
        self.init(attributedText: AttributedString(plainText))
    }

    init(attributedText: AttributedString) {
        document = Self.document(from: attributedText)
    }

    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let document = try? JSONDecoder().decode(ProseMirrorDocument.self, from: data) else {
            return nil
        }
        self.document = document
    }

    var attributedText: AttributedString {
        document.content.enumerated().reduce(into: AttributedString("")) { result, entry in
            if entry.offset > 0 {
                result += AttributedString("\n")
            }

            result += NativeEditorDocument.attributedText(
                from: NativeEditorDocument.inlineContent(from: entry.element.content ?? [])
            )
        }
    }

    var plainText: String {
        String(attributedText.characters)
    }

    var isEmpty: Bool {
        plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isSupportedForEditing: Bool {
        document.type == "doc"
            && document.content.allSatisfy(Self.isSupportedParagraph)
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(document),
            let string = String(data: data, encoding: .utf8)
        else {
            return #"{"type":"doc","content":[]}"#
        }
        return string
    }

    private static func document(from text: AttributedString) -> ProseMirrorDocument {
        let inlineNodes = NativeEditorDocument.inlineNodes(from: text)
        var paragraphs: [[ProseMirrorNode]] = [[]]

        for node in inlineNodes {
            if node.type == "hardBreak" {
                paragraphs.append([])
            } else {
                paragraphs[paragraphs.index(before: paragraphs.endIndex)].append(node)
            }
        }

        return ProseMirrorDocument(content: paragraphs.map { nodes in
            ProseMirrorNode(type: "paragraph", content: nodes)
        })
    }

    private static func isSupportedParagraph(_ node: ProseMirrorNode) -> Bool {
        guard node.type == "paragraph",
              node.attrs?.isEmpty != false,
              node.marks?.isEmpty != false,
              node.text == nil else {
            return false
        }

        return (node.content ?? []).allSatisfy(isSupportedInlineNode)
    }

    private static func isSupportedInlineNode(_ node: ProseMirrorNode) -> Bool {
        guard (node.marks ?? []).allSatisfy(isSupportedMark) else { return false }

        switch node.type {
        case "text":
            return node.text != nil
                && node.attrs?.isEmpty != false
                && node.content == nil
        case "hardBreak":
            return node.attrs?.isEmpty != false
                && node.content == nil
                && node.text == nil
        case "mention":
            let entityType = node.attrs?["entityType"]?.stringValue
            return entityType == "user" || entityType == "page"
        default:
            return false
        }
    }

    private static func isSupportedMark(_ mark: ProseMirrorMark) -> Bool {
        switch mark.type {
        case "bold", "italic", "strike", "code":
            return mark.attrs?.isEmpty != false
        case "link":
            guard let href = mark.attrs?["href"]?.stringValue else { return false }
            return NativeEditorDocument.preservedLink(
                href: href,
                isInternal: mark.attrs?["internal"]?.boolValue ?? false
            ) != nil
        default:
            return false
        }
    }
}
