import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorViewModelTests {
    @Test func togglesInlineMarkAcrossActiveBlockWhenSelectionIsMissing() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Native editor"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.toggleInlineMark(.bold)

        let updatedBlock = viewModel.document.blocks[0]
        #expect(updatedBlock.text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(viewModel.isDirty == true)
    }

    @Test func changesActiveBlockKind() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Section"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.setActiveBlockKind(.heading(level: 2))

        #expect(viewModel.document.blocks[0].kind == .heading(level: 2))
        #expect(viewModel.isDirty == true)
    }

    @Test func filtersSlashCommandsFromActiveBlockText() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/to"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.isShowingSlashCommands == true)
        #expect(viewModel.slashCommandQuery == "to")
        #expect(viewModel.filteredSlashCommands.map(\.title) == ["To-do List"])
    }

    @Test func applyingSlashCommandTransformsActiveBlockAndClearsSlashToken() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/h1"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.heading1)

        #expect(viewModel.document.blocks[0].kind == .heading(level: 1))
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
        #expect(viewModel.isShowingSlashCommands == false)
        #expect(viewModel.isDirty == true)
    }

    @Test func applyingTableCommandCreatesRawTableBlock() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/table"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.table)

        guard case .table(let table) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.count == 2)
        #expect(viewModel.document.blocks[0].isEditable == false)
        #expect(viewModel.document.proseMirrorDocument.content.first?.type == "table")
        #expect(viewModel.document.proseMirrorDocument.content.first?.content?.count == 2)
    }

    @Test func applyingMermaidCommandCreatesEditableMermaidCodeBlock() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/mermaid"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.mermaid)

        #expect(viewModel.document.blocks[0].kind == .codeBlock(language: "mermaid"))
        #expect(viewModel.document.blocks[0].isEditable == true)
        #expect(viewModel.document.proseMirrorDocument.content.first?.type == "codeBlock")
        #expect(viewModel.document.proseMirrorDocument.content.first?.attrs?["language"] == .string("mermaid"))
    }

    @Test func insertingUploadedImageReplacesActiveBlockWithDocmostNode() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/image"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertUploadedAttachment(uploadedAttachment(), as: .image)

        let updatedBlock = viewModel.document.blocks[0]
        guard case .image(let image) = updatedBlock.kind else {
            Issue.record("Expected image block")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(updatedBlock.id == block.id)
        #expect(updatedBlock.isEditable == false)
        #expect(image.source == "/api/files/attachment-1/Report.pdf")
        #expect(image.attachmentID == "attachment-1")
        #expect(image.sizeInBytes == 4096)
        #expect(node?.type == "image")
        #expect(node?.attrs?["src"] == .string("/api/files/attachment-1/Report.pdf"))
        #expect(node?.attrs?["attachmentId"] == .string("attachment-1"))
        #expect(node?.attrs?["size"] == .int(4096))
        #expect(viewModel.isDirty == true)
    }

    @Test func insertingUploadedFileAppendsWhenNoTextBlockIsActive() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [])

        viewModel.insertUploadedAttachment(uploadedAttachment(), as: .file)

        #expect(viewModel.document.blocks.count == 1)
        let updatedBlock = viewModel.document.blocks[0]
        guard case .attachment(let attachment) = updatedBlock.kind else {
            Issue.record("Expected attachment block")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(attachment.url == "/api/files/attachment-1/Report.pdf")
        #expect(attachment.name == "Report.pdf")
        #expect(attachment.mimeType == "application/pdf")
        #expect(node?.type == "attachment")
        #expect(node?.attrs?["url"] == .string("/api/files/attachment-1/Report.pdf"))
        #expect(node?.attrs?["name"] == .string("Report.pdf"))
        #expect(node?.attrs?["mime"] == .string("application/pdf"))
        #expect(viewModel.selectedBlockID == updatedBlock.id)
    }

    @Test func deletesSelectedBlockAndKeepsAdjacentBlockActive() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let selectedBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Selected"), alignment: .left)
        let lastBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Last"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, selectedBlock, lastBlock])

        viewModel.selectBlock(selectedBlock.id)
        viewModel.deleteSelectedBlock()

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["First", "Last"])
        #expect(viewModel.selectedBlockID == nil)
        #expect(viewModel.activeBlockID == lastBlock.id)
        #expect(viewModel.isDirty == true)
    }

    @Test func selectingAlreadySelectedBlockClearsSelection() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Selected"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])

        viewModel.selectBlock(block.id)
        viewModel.selectBlock(block.id)

        #expect(viewModel.selectedBlockID == nil)
        #expect(viewModel.visibleBlockControlsID == block.id)
    }

    @Test func movesBlockBeforeDropTarget() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let secondBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Second"), alignment: .left)
        let thirdBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Third"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, secondBlock, thirdBlock])

        viewModel.moveBlock(thirdBlock.id, before: firstBlock.id)

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Third", "First", "Second"])
        #expect(viewModel.isDirty == true)
    }

    @Test func appliesHighlightTextColorAndInlineCommentMarks() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Marked text"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applyHighlight(color: "#FEF3C7", colorName: "yellow")
        viewModel.applyTextColor("#111827")
        viewModel.applyInlineComment(commentID: "comment-1")

        let marks = proseMirrorTextMarks(from: viewModel)
        #expect(marks.contains(ProseMirrorMark(
            type: "highlight",
            attrs: ["color": .string("#FEF3C7"), "colorName": .string("yellow")]
        )))
        #expect(marks.contains(ProseMirrorMark(type: "textStyle", attrs: ["color": .string("#111827")])))
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)]
        )))
        #expect(viewModel.isDirty == true)
    }

    @Test func appliesInlineCommentFromCapturedSelectionContext() throws {
        let text = AttributedString("Inline comment selection")
        let commentRange = try #require(text.range(of: "comment"))
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: text,
            alignment: .left,
            selection: AttributedTextSelection(range: commentRange)
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        let context = try #require(viewModel.activeInlineCommentContext)
        #expect(context.selectedText == "comment")

        viewModel.clearFocus()
        viewModel.applyInlineComment(commentID: "comment-1", to: context)

        let marks = proseMirrorTextMarks(from: viewModel)
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)]
        )))
    }

    @Test func insertsStatusAndMentionInlineAtoms() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("State "), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertStatusBadge(text: "Ship", color: "green")
        viewModel.insertMention(NativeEditorMention(
            identifier: "mention-1",
            label: "Roadmap",
            entityType: "page",
            entityID: "page-2",
            slugID: "roadmap-abc"
        ))

        let inlineNodes = proseMirrorInlineNodes(from: viewModel)
        #expect(inlineNodes.map(\.type) == ["text", "status", "mention"])
        #expect(inlineNodes[1].attrs?["text"] == .string("Ship"))
        #expect(inlineNodes[1].attrs?["color"] == .string("green"))
        #expect(inlineNodes[2].attrs?["label"] == .string("Roadmap"))
        #expect(inlineNodes[2].attrs?["entityType"] == .string("page"))
        #expect(inlineNodes[2].attrs?["slugId"] == .string("roadmap-abc"))
    }

    @Test func decodesRichInlineAtomsAsEditableAttributedText() throws {
        let proseMirrorDocument = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: NativeEditorInlineFixtures.richInline
        )
        let document = NativeEditorDocument(
            proseMirrorDocument: proseMirrorDocument
        )

        let block = try #require(document.blocks.first)

        #expect(block.isEditable == true)
        #expect(block.inlineContent == nil)
        #expect(String(block.text.characters).contains("Roadmap"))
        #expect(String(block.text.characters).contains("Ship"))
    }

    private func proseMirrorTextMarks(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorMark] {
        proseMirrorInlineNodes(from: viewModel).flatMap { $0.marks ?? [] }
    }

    private func proseMirrorInlineNodes(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorNode] {
        viewModel.document.proseMirrorDocument.content.first?.content ?? []
    }

    private func uploadedAttachment() -> DocmostAttachment {
        DocmostAttachment(
            id: "attachment-1",
            fileName: "Report.pdf",
            filePath: nil,
            fileSize: 4096,
            fileExt: "pdf",
            mimeType: "application/pdf",
            type: "file",
            creatorId: "user-1",
            pageId: "page-1",
            spaceId: "space-1",
            workspaceId: "workspace-1",
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil
        )
    }
}
