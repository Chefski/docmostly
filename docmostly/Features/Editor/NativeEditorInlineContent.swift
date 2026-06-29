import Foundation

nonisolated enum NativeEditorInlineContent: Equatable, Hashable, Sendable, Codable {
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
                case .unknown:
                    true
                case .underline, .highlight, .textColor, .subscript, .superscript, .comment:
                    false
                }
            }
        case .hardBreak:
            false
        case .mention, .status, .mathInline:
            false
        case .unsupported:
            true
        }
    }

    var requiresTableCellInlinePreservation: Bool {
        switch self {
        case .text(_, let marks):
            marks.isEmpty == false
        case .hardBreak:
            false
        case .mention, .status, .mathInline, .unsupported:
            true
        }
    }
}

nonisolated extension Array where Element == NativeEditorInlineContent {
    var plainText: String {
        map(\.plainText).joined()
    }

    var preservedForTableCell: [NativeEditorInlineContent]? {
        contains(where: \.requiresTableCellInlinePreservation) ? self : nil
    }
}

nonisolated enum NativeEditorTextMark: Equatable, Hashable, Sendable, Codable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case link(href: String, isInternal: Bool = false)
    case highlight(color: String?, colorName: String?)
    case textColor(String)
    case `subscript`
    case superscript
    case comment(commentID: String, isResolved: Bool)
    case unknown(ProseMirrorMark)
}

nonisolated struct NativeEditorMention: Equatable, Hashable, Sendable, Codable {
    var identifier: String?
    var label: String?
    var entityType: String?
    var entityID: String?
    var slugID: String?
    var creatorID: String?
    var anchorID: String?

    init(
        identifier: String? = nil,
        label: String? = nil,
        entityType: String? = nil,
        entityID: String? = nil,
        slugID: String? = nil,
        creatorID: String? = nil,
        anchorID: String? = nil
    ) {
        self.identifier = identifier
        self.label = label
        self.entityType = entityType
        self.entityID = entityID
        self.slugID = slugID
        self.creatorID = creatorID
        self.anchorID = anchorID
    }

    var displayText: String {
        if entityType == "user" {
            "@\(label ?? entityID ?? identifier ?? "Mention")"
        } else {
            label ?? entityID ?? identifier ?? "Mention"
        }
    }
}

nonisolated struct NativeEditorStatusBadge: Equatable, Hashable, Sendable, Codable {
    var text: String
    var color: String
}

nonisolated struct NativeEditorMathInline: Equatable, Hashable, Sendable, Codable {
    var text: String
}
