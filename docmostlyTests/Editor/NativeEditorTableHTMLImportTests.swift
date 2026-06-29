import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableHTMLImportTests {
    @Test func docmostHTMLTableImportsAsNativeTableBlock() throws {
        let markdown = """
        <div class="tableWrapper">
        <table>
        <thead>
        <tr>
        <th colspan="2" colwidth="120,160" data-background-color="#DBEAFE" data-background-color-name="blue">
        <p style="text-align: center">Phase</p>
        </th>
        </tr>
        </thead>
        <tbody>
        <tr>
        <td data-background-color="#FEF3C7" data-background-color-name="yellow"><p>Build</p></td>
        <td><p>Taylor</p></td>
        </tr>
        </tbody>
        </table>
        </div>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.count == 1)
        #expect(table.rows[0].cells[0].plainText == "Phase")
        #expect(table.rows[0].cells[0].isHeader)
        #expect(table.rows[0].cells[0].textAlignment == .center)
        #expect(table.rows[0].cells[0].backgroundColor == "#DBEAFE")
        #expect(table.rows[0].cells[0].backgroundColorName == "blue")
        #expect(table.rows[0].cells[0].columnSpan == 2)
        #expect(table.rows[0].cells[0].columnWidths == [120, 160])
        #expect(table.rows[1].cells.map(\.plainText) == ["Build", "Taylor"])
        #expect(table.rows[1].cells[0].backgroundColor == "#FEF3C7")
        #expect(table.rows[1].cells[0].backgroundColorName == "yellow")

        let node = NativeEditorDocument.node(from: block)
        #expect(node.type == "table")
        let headerCell = try #require(node.content?.first?.content?.first)
        #expect(headerCell.type == "tableHeader")
        #expect(headerCell.attrs?["colspan"] == .int(2))
        #expect(headerCell.attrs?["colwidth"] == .array([.int(120), .int(160)]))
        #expect(headerCell.attrs?["backgroundColor"] == .string("#DBEAFE"))
        #expect(headerCell.attrs?["backgroundColorName"] == .string("blue"))
    }

    @Test func docmostHTMLTableCellPreservesInlineAtomsAndCommentMarks() throws {
        let mentionHTML = #"<span data-type="mention" data-id="mention-1" data-label="Taylor" "# +
            #"data-entity-type="user" data-entity-id="user-1">@Taylor</span>"#
        let commentHTML = #"<span class="comment-mark" data-comment-id="comment-1" "# +
            #"data-resolved="true">review spec</span>"#
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td><p>Ask \(mentionHTML) to \(commentHTML)</p></td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        #expect(cell.plainText == "Ask @Taylor to review spec")
        #expect(cell.inlineContent?.contains {
            if case .mention(let mention, _) = $0 {
                return mention.identifier == "mention-1" &&
                    mention.label == "Taylor" &&
                    mention.entityType == "user" &&
                    mention.entityID == "user-1"
            }

            return false
        } == true)
        #expect(cell.inlineContent?.contains {
            if case .text("review spec", let marks) = $0 {
                return marks.contains(.comment(commentID: "comment-1", isResolved: true))
            }

            return false
        } == true)

        let node = NativeEditorDocument.node(from: block)
        let paragraphContent = try #require(node.content?.first?.content?.first?.content?.first?.content)
        #expect(paragraphContent.map(\.type) == ["text", "mention", "text", "text"])
        #expect(paragraphContent[1].attrs?["id"] == .string("mention-1"))
        #expect(paragraphContent[3].marks == [
            ProseMirrorMark(type: "comment", attrs: ["commentId": .string("comment-1"), "resolved": .bool(true)])
        ])
    }

    @Test func docmostHTMLTableCellPreservesBlockContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <h2>Phase</h2>
        <p>Ship native tables</p>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText == "PhaseShip native tables")
        #expect(preservedContent.map(\.type) == ["heading", "paragraph"])
        #expect(preservedContent[0].attrs?["level"] == .int(2))

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["heading", "paragraph"])
        #expect(cellContent[0].attrs?["level"] == .int(2))
        #expect(cellContent[0].content?.first?.text == "Phase")
        #expect(cellContent[1].content?.first?.text == "Ship native tables")
    }

    @Test func docmostHTMLTableCellPreservesCodeBlockContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <pre><code class="language-swift">let value = &lt;draft&gt;
        print(value)</code></pre>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText == """
        let value = <draft>
        print(value)
        """)
        #expect(preservedContent.map(\.type) == ["codeBlock"])
        #expect(preservedContent[0].attrs?["language"] == .string("swift"))

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["codeBlock"])
        #expect(cellContent[0].attrs?["language"] == .string("swift"))
        #expect(cellContent[0].content?.first?.text == """
        let value = <draft>
        print(value)
        """)
    }

    @Test func docmostHTMLTableCellPreservesListContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <ul>
        <li><p>Plan rollout</p></li>
        <li><p>Measure feedback</p></li>
        </ul>
        <ol start="3">
        <li><p>Ship polish</p></li>
        </ol>
        <ul data-type="taskList">
        <li data-type="taskItem" data-checked="true"><p>Confirm docs</p></li>
        </ul>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText == "Plan rolloutMeasure feedbackShip polishConfirm docs")
        #expect(preservedContent.map(\.type) == ["bulletList", "orderedList", "taskList"])

        let bulletItems = try #require(preservedContent[0].content)
        #expect(bulletItems.map(\.type) == ["listItem", "listItem"])
        #expect(bulletItems[0].content?.first?.content?.first?.text == "Plan rollout")
        #expect(bulletItems[1].content?.first?.content?.first?.text == "Measure feedback")
        #expect(preservedContent[1].attrs?["start"] == .int(3))
        #expect(preservedContent[1].content?.first?.content?.first?.content?.first?.text == "Ship polish")
        #expect(preservedContent[2].content?.first?.type == "taskItem")
        #expect(preservedContent[2].content?.first?.attrs?["checked"] == .bool(true))
        #expect(preservedContent[2].content?.first?.content?.first?.content?.first?.text == "Confirm docs")

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["bulletList", "orderedList", "taskList"])
        #expect(cellContent[1].attrs?["start"] == .int(3))
        #expect(cellContent[2].content?.first?.attrs?["checked"] == .bool(true))
    }

    @Test func docmostHTMLTableCellPreservesCalloutContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="callout" data-callout-type="warning" data-callout-icon="rocket">
        <p>Check launch notes</p>
        </div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText == "Check launch notes")
        #expect(preservedContent.map(\.type) == ["callout"])
        #expect(preservedContent[0].attrs?["type"] == .string("warning"))
        #expect(preservedContent[0].attrs?["icon"] == .string("rocket"))
        #expect(preservedContent[0].content?.first?.type == "paragraph")
        #expect(preservedContent[0].content?.first?.content?.first?.text == "Check launch notes")

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["callout"])
        #expect(cellContent[0].attrs?["type"] == .string("warning"))
        #expect(cellContent[0].attrs?["icon"] == .string("rocket"))
        #expect(cellContent[0].content?.first?.content?.first?.text == "Check launch notes")
    }

    @Test func docmostHTMLTableCellPreservesImageContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <img src="/api/attachments/img/image-1.png" alt="Architecture" title="System diagram"
        width="640" height="360" data-align="center" data-attachment-id="image-1"
        data-size="2048" data-aspect-ratio="1.7777778">
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText.isEmpty)
        #expect(preservedContent.map(\.type) == ["image"])
        #expect(preservedContent[0].attrs?["src"] == .string("/api/attachments/img/image-1.png"))
        #expect(preservedContent[0].attrs?["alt"] == .string("Architecture"))
        #expect(preservedContent[0].attrs?["title"] == .string("System diagram"))
        #expect(preservedContent[0].attrs?["width"] == .int(640))
        #expect(preservedContent[0].attrs?["height"] == .int(360))
        #expect(preservedContent[0].attrs?["align"] == .string("center"))
        #expect(preservedContent[0].attrs?["attachmentId"] == .string("image-1"))
        #expect(preservedContent[0].attrs?["size"] == .int(2048))
        #expect(preservedContent[0].attrs?["aspectRatio"] == .double(1.7777778))

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["image"])
        #expect(cellContent[0].attrs?["attachmentId"] == .string("image-1"))
        #expect(cellContent[0].attrs?["aspectRatio"] == .double(1.7777778))
    }

    @Test func docmostHTMLTableCellPreservesVideoAndAudioContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <video src="/api/files/video-1/Launch.mp4" aria-label="Launch demo"
        width="75%" height="360" data-align="right" data-attachment-id="video-1"
        data-size="4096" data-aspect-ratio="1.7777778" controls="true">
        <source src="/api/files/video-1/Launch.mp4">
        </video>
        <audio src="/api/files/audio-1/Briefing.m4a" data-attachment-id="audio-1"
        data-size="2048" controls="true" preload="metadata">
        <source src="/api/files/audio-1/Briefing.m4a">
        </audio>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText.isEmpty)
        #expect(preservedContent.map(\.type) == ["video", "audio"])
        #expect(preservedContent[0].attrs?["src"] == .string("/api/files/video-1/Launch.mp4"))
        #expect(preservedContent[0].attrs?["alt"] == .string("Launch demo"))
        #expect(preservedContent[0].attrs?["width"] == .string("75%"))
        #expect(preservedContent[0].attrs?["height"] == .int(360))
        #expect(preservedContent[0].attrs?["align"] == .string("right"))
        #expect(preservedContent[0].attrs?["attachmentId"] == .string("video-1"))
        #expect(preservedContent[0].attrs?["size"] == .int(4096))
        #expect(preservedContent[0].attrs?["aspectRatio"] == .double(1.7777778))
        #expect(preservedContent[1].attrs?["src"] == .string("/api/files/audio-1/Briefing.m4a"))
        #expect(preservedContent[1].attrs?["attachmentId"] == .string("audio-1"))
        #expect(preservedContent[1].attrs?["size"] == .int(2048))

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["video", "audio"])
        #expect(cellContent[0].attrs?["attachmentId"] == .string("video-1"))
        #expect(cellContent[1].attrs?["attachmentId"] == .string("audio-1"))
    }
}
