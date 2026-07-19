import Testing
@testable import docmostly

struct NativeEditorSimpleContentSafetyTests {
    @Test func acceptsEmptyAndSinglePlainParagraphContent() {
        let plainNodes = [
            ProseMirrorNode(
                type: "paragraph",
                content: [
                    ProseMirrorNode(type: "text", text: "First line"),
                    ProseMirrorNode(type: "hardBreak"),
                    ProseMirrorNode(type: "text", text: "Second line")
                ]
            )
        ]

        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: []) == "")
        #expect(
            NativeEditorSimpleContentSafety.plainBlockText(in: plainNodes) ==
                "First line\nSecond line"
        )
    }

    @Test func acceptsDocmostParagraphIdentityAndTextLayoutAttributes() {
        let reloadedParagraph = ProseMirrorNode(
            type: "paragraph",
            attrs: [
                "id": .string("paragraph-1"),
                "indent": .int(1),
                "textAlign": .string("center")
            ],
            content: [ProseMirrorNode(type: "text", text: "Still editable")]
        )

        #expect(
            NativeEditorSimpleContentSafety.plainBlockText(in: [reloadedParagraph]) ==
                "Still editable"
        )
    }

    @Test func acceptsEmptyAndPlainInlineSummaryContent() {
        let plainNodes = [
            ProseMirrorNode(type: "text", text: "Summary"),
            ProseMirrorNode(type: "hardBreak"),
            ProseMirrorNode(type: "text", text: "continued")
        ]

        #expect(NativeEditorSimpleContentSafety.plainInlineText(in: []) == "")
        #expect(
            NativeEditorSimpleContentSafety.plainInlineText(in: plainNodes) ==
                "Summary\ncontinued"
        )
    }

    @Test func rejectsMarksSemanticAtomsAndUnknownNodes() {
        let markedParagraph = paragraph(
            containing: ProseMirrorNode(
                type: "text",
                marks: [ProseMirrorMark(type: "bold")],
                text: "Important"
            )
        )
        let mentionParagraph = paragraph(
            containing: ProseMirrorNode(
                type: "mention",
                attrs: ["id": .string("user-1")]
            )
        )
        let unknownParagraph = paragraph(containing: ProseMirrorNode(type: "futureInlineNode"))

        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [markedParagraph]) == nil)
        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [mentionParagraph]) == nil)
        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [unknownParagraph]) == nil)
    }

    @Test func rejectsNestedBlocksMultipleParagraphsAndUnknownMetadata() {
        let nestedList = ProseMirrorNode(
            type: "bulletList",
            content: [
                ProseMirrorNode(
                    type: "listItem",
                    content: [paragraph(containing: ProseMirrorNode(type: "text", text: "Item"))]
                )
            ]
        )
        let attributedParagraph = ProseMirrorNode(
            type: "paragraph",
            attrs: ["futureAttribute": .string("preserve-me")],
            content: [ProseMirrorNode(type: "text", text: "Future content")]
        )
        let firstParagraph = paragraph(containing: ProseMirrorNode(type: "text", text: "One"))
        let secondParagraph = paragraph(containing: ProseMirrorNode(type: "text", text: "Two"))

        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [nestedList]) == nil)
        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [attributedParagraph]) == nil)
        #expect(
            NativeEditorSimpleContentSafety.plainBlockText(
                in: [firstParagraph, secondParagraph]
            ) == nil
        )
    }

    @Test func rejectsMalformedHardBreaksAndNestedInlineContent() {
        let attributedBreak = paragraph(
            containing: ProseMirrorNode(
                type: "hardBreak",
                attrs: ["future": .bool(true)]
            )
        )
        let nestedText = paragraph(
            containing: ProseMirrorNode(
                type: "text",
                content: [ProseMirrorNode(type: "text", text: "Nested")],
                text: "Outer"
            )
        )

        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [attributedBreak]) == nil)
        #expect(NativeEditorSimpleContentSafety.plainBlockText(in: [nestedText]) == nil)
    }

    private func paragraph(containing node: ProseMirrorNode) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: [node])
    }
}
