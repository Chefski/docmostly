import Foundation

enum NativeEditorInlineContent: Equatable, Hashable, Sendable, Codable {
    case text(String, marks: [NativeEditorTextMark])
    case hardBreak
    case mention(NativeEditorMention)
    case status(NativeEditorStatusBadge)
    case mathInline(NativeEditorMathInline)
    case unsupported(ProseMirrorNode)

    var plainText: String {
        switch self {
        case .text(let text, _):
            text
        case .hardBreak:
            "\n"
        case .mention(let mention):
            mention.displayText
        case .status(let status):
            status.text
        case .mathInline(let math):
            math.text
        case .unsupported(let node):
            node.text ?? ""
        }
    }

    var requiresRawPreservation: Bool {
        switch self {
        case .text(_, let marks):
            marks.contains { mark in
                switch mark {
                case .bold, .italic, .strikethrough, .code, .link:
                    false
                case .underline, .highlight, .textColor, .subscript, .superscript, .comment, .unknown:
                    true
                }
            }
        case .hardBreak:
            false
        case .mention, .status, .mathInline, .unsupported:
            true
        }
    }
}

enum NativeEditorTextMark: Equatable, Hashable, Sendable, Codable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case link(href: String)
    case highlight(color: String?, colorName: String?)
    case textColor(String)
    case `subscript`
    case superscript
    case comment(commentID: String, isResolved: Bool)
    case unknown(ProseMirrorMark)
}

struct NativeEditorMention: Equatable, Hashable, Sendable, Codable {
    var identifier: String?
    var label: String?
    var entityType: String?
    var entityID: String?
    var slugID: String?
    var creatorID: String?
    var anchorID: String?

    var displayText: String {
        if entityType == "user" {
            "@\(label ?? entityID ?? identifier ?? "Mention")"
        } else {
            label ?? entityID ?? identifier ?? "Mention"
        }
    }
}

struct NativeEditorStatusBadge: Equatable, Hashable, Sendable, Codable {
    var text: String
    var color: String
}

struct NativeEditorMathInline: Equatable, Hashable, Sendable, Codable {
    var text: String
}
