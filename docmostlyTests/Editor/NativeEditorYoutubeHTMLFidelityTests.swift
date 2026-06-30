import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorYoutubeHTMLFidelityTests {
    @Test func importsDocmostYoutubeHTMLAsNativeEmbedBlock() throws {
        let markdown = """
        <div data-youtube-video="">
        <iframe src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?start=42"
        width="640" height="360"></iframe>
        </div>
        """
        let expectedMarkdown = """
        <div data-youtube-video="">
        <iframe src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?start=42" width="640" height="360"></iframe>
        </div>
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 1)
        guard case .embed(let embed) = blocks[0].kind else {
            Issue.record("Expected Docmost YouTube HTML to import as a native embed block.")
            return
        }

        #expect(embed.source == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        #expect(embed.provider == "YouTube")
        #expect(embed.width == "640")
        #expect(embed.height == "360")
        #expect(blocks[0].rawNode?.type == "youtube")
        #expect(blocks[0].rawNode?.attrs?["src"] == .string("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        #expect(blocks[0].rawNode?.attrs?["start"] == .int(42))
        #expect(blocks[0].rawNode?.attrs?["width"] == .int(640))
        #expect(blocks[0].rawNode?.attrs?["height"] == .int(360))
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == expectedMarkdown)
    }
}
