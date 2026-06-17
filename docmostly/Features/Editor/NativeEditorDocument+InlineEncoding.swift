import Foundation

extension NativeEditorDocument {
    static func marks(from run: AttributedString.Runs.Run) -> [ProseMirrorMark]? {
        var marks: [ProseMirrorMark] = []
        appendPresentationMarks(from: run, to: &marks)
        appendUnderlineMark(from: run, to: &marks)
        appendBaselineMark(from: run, to: &marks)
        appendLinkMark(from: run, to: &marks)
        return marks.isEmpty ? nil : marks
    }

    static func proseMirrorMark(from mark: NativeEditorTextMark) -> ProseMirrorMark {
        if let simpleMark = simpleProseMirrorMark(from: mark) {
            return simpleMark
        }

        return richProseMirrorMark(from: mark)
    }

    static func attrs(from mention: NativeEditorMention) -> [String: ProseMirrorJSONValue] {
        optionalAttrs([
            "id": mention.identifier,
            "label": mention.label,
            "entityType": mention.entityType,
            "entityId": mention.entityID,
            "slugId": mention.slugID,
            "creatorId": mention.creatorID,
            "anchorId": mention.anchorID
        ]) ?? [:]
    }

    private static func appendPresentationMarks(
        from run: AttributedString.Runs.Run,
        to marks: inout [ProseMirrorMark]
    ) {
        let intent = run.inlinePresentationIntent ?? []
        let supportedIntents: [(InlinePresentationIntent, ProseMirrorMark)] = [
            (.stronglyEmphasized, ProseMirrorMark(type: "bold")),
            (.emphasized, ProseMirrorMark(type: "italic")),
            (.strikethrough, ProseMirrorMark(type: "strike")),
            (.code, ProseMirrorMark(type: "code"))
        ]

        for supportedIntent in supportedIntents where intent.contains(supportedIntent.0) {
            appendMarkIfMissing(supportedIntent.1, to: &marks)
        }
    }

    private static func appendUnderlineMark(
        from run: AttributedString.Runs.Run,
        to marks: inout [ProseMirrorMark]
    ) {
        if run.underlineStyle != nil {
            appendMarkIfMissing(ProseMirrorMark(type: "underline"), to: &marks)
        }
    }

    private static func appendBaselineMark(
        from run: AttributedString.Runs.Run,
        to marks: inout [ProseMirrorMark]
    ) {
        guard let baselineOffset = run.baselineOffset, baselineOffset != 0 else { return }

        let markType = baselineOffset > 0 ? "superscript" : "subscript"
        appendMarkIfMissing(ProseMirrorMark(type: markType), to: &marks)
    }

    private static func appendLinkMark(
        from run: AttributedString.Runs.Run,
        to marks: inout [ProseMirrorMark]
    ) {
        if let href = run.link?.absoluteString {
            appendMarkIfMissing(ProseMirrorMark(type: "link", attrs: ["href": .string(href)]), to: &marks)
        }
    }

    private static func simpleProseMirrorMark(from mark: NativeEditorTextMark) -> ProseMirrorMark? {
        switch mark {
        case .bold:
            ProseMirrorMark(type: "bold")
        case .italic:
            ProseMirrorMark(type: "italic")
        case .underline:
            ProseMirrorMark(type: "underline")
        case .strikethrough:
            ProseMirrorMark(type: "strike")
        case .code:
            ProseMirrorMark(type: "code")
        case .subscript:
            ProseMirrorMark(type: "subscript")
        case .superscript:
            ProseMirrorMark(type: "superscript")
        default:
            nil
        }
    }

    private static func richProseMirrorMark(from mark: NativeEditorTextMark) -> ProseMirrorMark {
        switch mark {
        case .link(let href):
            ProseMirrorMark(type: "link", attrs: ["href": .string(href)])
        case .highlight(let color, let colorName):
            ProseMirrorMark(type: "highlight", attrs: optionalAttrs(markAttrs(color, colorName)))
        case .textColor(let color):
            ProseMirrorMark(type: "textStyle", attrs: ["color": .string(color)])
        case .comment(let commentID, let isResolved):
            ProseMirrorMark(type: "comment", attrs: commentAttrs(commentID, isResolved))
        case .unknown(let mark):
            mark
        default:
            ProseMirrorMark(type: "unknown")
        }
    }

    private static func markAttrs(_ color: String?, _ colorName: String?) -> [String: String?] {
        [
            "color": color,
            "colorName": colorName
        ]
    }

    private static func commentAttrs(
        _ commentID: String,
        _ isResolved: Bool
    ) -> [String: ProseMirrorJSONValue] {
        [
            "commentId": .string(commentID),
            "resolved": .bool(isResolved)
        ]
    }

    private static func appendMarkIfMissing(_ mark: ProseMirrorMark, to marks: inout [ProseMirrorMark]) {
        guard marks.contains(mark) == false else { return }
        marks.append(mark)
    }
}
