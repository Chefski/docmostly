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
        #expect(viewModel.filteredSlashCommands.map(\.title) == ["To-do list", "Toggle block"])
    }

    @Test func slashCommandFilteringUsesSubtitlesWhenTitlesDoNotMatch() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/equation"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        let titles = viewModel.filteredSlashCommands.map(\.title)
        #expect(titles.contains("Math inline"))
        #expect(titles.contains("Math block"))
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

    @Test func appliesHeadingThreeSlashCommand() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/heading 3"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.filteredSlashCommands.map(\.title).contains("Heading 3"))

        viewModel.applySlashCommand(.heading3)

        #expect(viewModel.document.blocks[0].kind == .heading(level: 3))
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
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
        expectDocmostDefaultTableShape(table)
        #expect(viewModel.document.blocks[0].isEditable == false)
        #expect(viewModel.document.proseMirrorDocument.content.first?.type == "table")
        #expect(viewModel.document.proseMirrorDocument.content.first?.content?.count == 3)
    }

    @Test func slashCommandInventoryIncludesMediaFileAndDiagramBlocks() {
        let titles = NativeEditorCommand.richCases.map(\.title)

        #expect(titles.contains("Image"))
        #expect(titles.contains("Video"))
        #expect(titles.contains("Audio"))
        #expect(titles.contains("Embed PDF"))
        #expect(titles.contains("File attachment"))
        #expect(titles.contains("Draw.io (diagrams.net)"))
        #expect(titles.contains("Excalidraw (Whiteboard)"))
    }

    @Test func slashCommandInventoryIncludesInlineEverydayCommands() {
        let titles = NativeEditorCommand.allCases.map(\.title)

        #expect(titles.contains("Date"))
        #expect(titles.contains("Time"))
        #expect(titles.contains("Status"))
        #expect(titles.contains("Emoji"))
        #expect(titles.contains("Math inline"))
    }

    @Test func mediaSlashCommandsMapToAttachmentImportKinds() {
        #expect(NativeEditorCommand.image.attachmentImportKind == .image)
        #expect(NativeEditorCommand.video.attachmentImportKind == .video)
        #expect(NativeEditorCommand.audio.attachmentImportKind == .audio)
        #expect(NativeEditorCommand.pdf.attachmentImportKind == .pdf)
        #expect(NativeEditorCommand.fileAttachment.attachmentImportKind == .file)
        #expect(NativeEditorCommand.table.attachmentImportKind == nil)
        #expect(NativeEditorCommand.drawio.attachmentImportKind == nil)
    }

    @Test func applyingMediaSlashCommandsCreatesPlaceholderBlocks() {
        let expectations = [
            SlashCommandExpectation(command: .image, nodeType: "image", label: "Image"),
            SlashCommandExpectation(command: .video, nodeType: "video", label: "Video"),
            SlashCommandExpectation(command: .audio, nodeType: "audio", label: "Audio"),
            SlashCommandExpectation(command: .pdf, nodeType: "pdf", label: "PDF"),
            SlashCommandExpectation(command: .fileAttachment, nodeType: "attachment", label: "File attachment"),
            SlashCommandExpectation(command: .drawio, nodeType: "drawio", label: "Draw.io diagram"),
            SlashCommandExpectation(command: .excalidraw, nodeType: "excalidraw", label: "Excalidraw diagram")
        ]

        for expectation in expectations {
            let block = NativeEditorBlock(
                kind: .paragraph,
                text: AttributedString("/\(expectation.command.rawValue)"),
                alignment: .left
            )
            let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
            viewModel.document = NativeEditorDocument(blocks: [block])
            viewModel.focus(blockID: block.id)

            viewModel.applySlashCommand(expectation.command)

            #expect(viewModel.document.blocks[0].id == block.id)
            #expect(viewModel.document.blocks[0].kind.accessibilityLabel == expectation.label)
            #expect(viewModel.document.blocks[0].isEditable == false)
            #expect(viewModel.document.proseMirrorDocument.content.first?.type == expectation.nodeType)
        }
    }

    @Test func applyingMermaidCommandCreatesEditableMermaidCodeBlock() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/mermaid"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.mermaid)

        let mermaidSeed = "flowchart LR\n    A --> B"
        #expect(viewModel.document.blocks[0].kind == .codeBlock(language: "mermaid"))
        #expect(String(viewModel.document.blocks[0].text.characters) == mermaidSeed)
        #expect(viewModel.document.blocks[0].isEditable == true)
        #expect(viewModel.document.proseMirrorDocument.content.first?.type == "codeBlock")
        #expect(viewModel.document.proseMirrorDocument.content.first?.attrs?["language"] == .string("mermaid"))
        #expect(viewModel.document.proseMirrorDocument.content.first?.content?.first?.text == mermaidSeed)
    }

    @Test func applyingDateTimeAndEmojiSlashCommandsReplacesSlashToken() throws {
        var calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        calendar.timeZone = utc
        let now = try #require(calendar.date(from: DateComponents(
            timeZone: utc,
            year: 2026,
            month: 6,
            day: 28,
            hour: 13,
            minute: 45
        )))

        let dateText = inlineSlashCommandText(command: .date, slashText: "/date", now: now)
        let timeText = inlineSlashCommandText(command: .time, slashText: "/time", now: now)
        let emojiText = inlineSlashCommandText(command: .emoji, slashText: "/emoji", now: now)

        #expect(dateText.contains("2026"))
        #expect(dateText.contains("/date") == false)
        #expect(timeText.isEmpty == false)
        #expect(timeText.contains("/time") == false)
        #expect(emojiText == ":")
    }

    @Test func applyingStatusSlashCommandCreatesInlineStatusAtom() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/status"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.filteredSlashCommands.map(\.title).contains("Status"))

        viewModel.applySlashCommand(.status)

        let inlineNodes = proseMirrorInlineNodes(from: viewModel)
        #expect(inlineNodes.map(\.type) == ["status"])
        #expect(inlineNodes.first?.attrs?["text"] == .string("Status"))
        #expect(inlineNodes.first?.attrs?["color"] == .string("gray"))
    }

    @Test func applyingMathInlineSlashCommandCreatesInlineMathAtom() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/math inline"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.filteredSlashCommands.map(\.title).contains("Math inline"))

        viewModel.applySlashCommand(.mathInline)

        let inlineNodes = proseMirrorInlineNodes(from: viewModel)
        #expect(inlineNodes.map(\.type) == ["mathInline"])
        #expect(inlineNodes.first?.attrs?["text"] == .string("x = y"))
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

    @Test func insertingUploadedVideoPreservesFileTitleInDocmostNode() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/video"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertUploadedAttachment(
            uploadedAttachment(fileName: "Launch demo.mp4", mimeType: "video/mp4", fileExt: "mp4"),
            as: .video
        )

        let updatedBlock = viewModel.document.blocks[0]
        guard case .video(let video) = updatedBlock.kind else {
            Issue.record("Expected video block")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(video.source == "/api/files/attachment-1/Launch demo.mp4")
        #expect(video.title == "Launch demo.mp4")
        #expect(video.attachmentID == "attachment-1")
        #expect(video.sizeInBytes == 4096)
        #expect(String(updatedBlock.text.characters) == "Launch demo.mp4")
        #expect(node?.type == "video")
        #expect(node?.attrs?["src"] == .string("/api/files/attachment-1/Launch demo.mp4"))
        #expect(node?.attrs?["title"] == .string("Launch demo.mp4"))
        #expect(node?.attrs?["attachmentId"] == .string("attachment-1"))
        #expect(node?.attrs?["size"] == .int(4096))
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

    private func inlineSlashCommandText(
        command: NativeEditorCommand,
        slashText: String,
        now: Date
    ) -> String {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(slashText), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(command, now: now)

        return String(viewModel.document.blocks[0].text.characters)
    }

    private func uploadedAttachment(
        fileName: String = "Report.pdf",
        mimeType: String = "application/pdf",
        fileExt: String = "pdf"
    ) -> DocmostAttachment {
        DocmostAttachment(
            id: "attachment-1",
            fileName: fileName,
            filePath: nil,
            fileSize: 4096,
            fileExt: fileExt,
            mimeType: mimeType,
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

private struct SlashCommandExpectation {
    let command: NativeEditorCommand
    let nodeType: String
    let label: String
}

@MainActor
private func proseMirrorInlineNodes(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorNode] {
    viewModel.document.proseMirrorDocument.content.first?.content ?? []
}

private func expectDocmostDefaultTableShape(_ table: NativeEditorTable) {
    #expect(table.rows.count == 3)
    #expect(table.columnCount == 3)
    #expect(table.rows.first?.cells.allSatisfy(\.isHeader) == true)
    #expect(table.rows.dropFirst().flatMap(\.cells).allSatisfy { $0.isHeader == false })
}
