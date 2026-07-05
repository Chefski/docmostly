import Foundation
import Testing
@testable import docmostly

struct AttachmentLinkTests {
    @Test func buildsAbsoluteAttachmentURL() throws {
        let link = DocmostAttachmentLink(
            id: "file-1",
            fileName: "diagram.svg",
            path: "/api/files/file-1/diagram.svg"
        )

        let url = try #require(link.url(serverURLString: "https://notes.example.com"))

        #expect(url.absoluteString == "https://notes.example.com/api/files/file-1/diagram.svg")
    }

    @Test func buildsEncodedDocmostFilePath() {
        let path = DocmostAttachmentLink.path(id: "file-1", fileName: "Launch demo #1.pdf")

        #expect(path == "/api/files/file-1/Launch%20demo%20%231.pdf")
    }

    @Test func attachmentExtractionReadsDocmostFileBlockMetadata() throws {
        let html = """
        <div data-type="attachment"
          data-attachment-url="/api/files/file-1/Archive%20Plan.pdf"
          data-attachment-name="Archive Plan.pdf"
          data-attachment-mime="application/pdf"
          data-attachment-size="2048"
          data-attachment-id="file-1">
          <a href="/api/files/file-1/Archive%20Plan.pdf" class="attachment">Archive Plan.pdf</a>
        </div>
        """

        let link = try #require(AttachmentExtractor.extractLinks(fromHTML: html).first)

        #expect(link.id == "file-1")
        #expect(link.fileName == "Archive Plan.pdf")
        #expect(link.mimeType == "application/pdf")
        #expect(link.fileSize == 2_048)
        #expect(link.path == "/api/files/file-1/Archive%20Plan.pdf")
    }

    @Test func attachmentExtractionReadsNativeProseMirrorAttachmentNodes() throws {
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "attachment",
                attrs: [
                    "attachmentId": .string("file-1"),
                    "url": .string("/api/files/file-1/Archive%20Plan.pdf"),
                    "name": .string("Archive Plan.pdf"),
                    "mime": .string("application/pdf"),
                    "size": .int(4096)
                ]
            )
        ])

        let link = try #require(AttachmentExtractor.extractLinks(from: document).first)

        #expect(link.id == "file-1")
        #expect(link.fileName == "Archive Plan.pdf")
        #expect(link.mimeType == "application/pdf")
        #expect(link.fileSize == 4_096)
    }

    @Test func attachmentExtractionCapsLinkCountAndRejectsTraversalSegments() {
        let safeLinks = (0..<(AttachmentExtractor.maximumLinks + 10))
            .map { "<a href=\"/api/files/file-\($0)/diagram-\($0).svg\">" }
            .joined()
        let html = safeLinks + "<a href=\"/api/files/file-bad/..%2Fsecret.txt\">"

        let links = AttachmentExtractor.extractLinks(fromHTML: html)

        #expect(links.count == AttachmentExtractor.maximumLinks)
        #expect(links.contains { $0.fileName.contains("secret") } == false)
    }

    @Test func attachmentExtractionSkipsOversizedHTML() {
        let html = String(repeating: "A", count: AttachmentExtractor.maximumHTMLCharacters + 1)

        #expect(AttachmentExtractor.extractLinks(fromHTML: html).isEmpty)
    }
}
