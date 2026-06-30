import Foundation

nonisolated enum NativeEditorInlineContent: Equatable, Hashable, Sendable, Codable {
    case text(String, marks: [NativeEditorTextMark])
    case hardBreak
    case mention(NativeEditorMention, marks: [NativeEditorTextMark] = [])
    case status(NativeEditorStatusBadge, marks: [NativeEditorTextMark] = [])
    case mathInline(NativeEditorMathInline, marks: [NativeEditorTextMark] = [])
    case unsupported(ProseMirrorNode)

    var plainText: String {
        switch self {
        case .text(let text, _):
            text
        case .hardBreak:
            "\n"
        case .mention(let mention, _):
            mention.displayText
        case .status(let status, _):
            status.text
        case .mathInline(let math, _):
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
        case .mention(_, let marks), .status(_, let marks), .mathInline(_, let marks):
            marks.contains { mark in
                if case .unknown = mark {
                    return true
                }

                return false
            }
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

nonisolated enum NativeEditorMentionNodeID {
    private static let hexDigits = Array("0123456789abcdef")

    static func make(now: Date = Date()) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let timestamp = timestampMilliseconds(from: now) & 0x0000_FFFF_FFFF_FFFF

        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        for index in 6..<bytes.count {
            bytes[index] = UInt8.random(in: UInt8.min...UInt8.max)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x70
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return uuidString(from: bytes)
    }

    private static func timestampMilliseconds(from date: Date) -> UInt64 {
        let milliseconds = date.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite, milliseconds > 0 else { return 0 }
        return UInt64(milliseconds.rounded(.down))
    }

    private static func uuidString(from bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(36)

        for (index, byte) in bytes.enumerated() {
            if index == 4 || index == 6 || index == 8 || index == 10 {
                result.append("-")
            }
            appendHex(byte, to: &result)
        }

        return result
    }

    private static func appendHex(_ byte: UInt8, to result: inout String) {
        result.append(hexDigits[Int(byte >> 4)])
        result.append(hexDigits[Int(byte & 0x0F)])
    }
}

nonisolated struct NativeEditorStatusBadge: Equatable, Hashable, Sendable, Codable {
    static let emptyDisplayText = "SET STATUS"

    var text: String
    var color: String

    var displayText: String {
        text.isEmpty ? Self.emptyDisplayText : text
    }
}

nonisolated struct NativeEditorMathInline: Equatable, Hashable, Sendable, Codable {
    static let emptyDisplayText = "SET EQUATION"

    var text: String

    var displayText: String {
        text.isEmpty ? Self.emptyDisplayText : text
    }
}
