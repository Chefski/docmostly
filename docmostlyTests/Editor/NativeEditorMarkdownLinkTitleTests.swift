import Foundation
import Testing
@testable import docmostly

struct NativeEditorMarkdownLinkTitleTests {
    @Test func imageTitleImportSupportsCommonMarkdownTitleDelimiters() throws {
        let markdownCases = [
            #"![Architecture](/files/image.png 'System diagram')"#,
            #"![Architecture](/files/image.png (System diagram))"#,
            #"![Architecture](</files/image.png> "System diagram")"#
        ]

        for markdown in markdownCases {
            let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

            guard case .image(let image) = block.kind else {
                Issue.record("Expected Markdown image to import as a native image block.")
                return
            }

            #expect(image.source == "/files/image.png")
            #expect(image.title == "System diagram")
            #expect(block.rawNode?.attrs?["title"] == .string("System diagram"))
        }
    }
}
