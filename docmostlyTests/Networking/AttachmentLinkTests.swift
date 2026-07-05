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

    @Test func buildsEncodedDocmostFilePathForLiteralPercentEscapes() {
        let path = DocmostAttachmentLink.path(id: "file-1", fileName: "not%2Fnested.pdf")

        #expect(path == "/api/files/file-1/not%252Fnested.pdf")
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

    @Test func attachmentExtractionScopesHTMLMetadataToMatchedAttachment() throws {
        let html = """
        <div data-type="attachment"
          data-attachment-url="/api/files/file-1/First.pdf"
          data-attachment-name="First.pdf"
          data-attachment-mime="application/pdf"
          data-attachment-size="1024"
          data-attachment-id="file-1">
          <a href="/api/files/file-1/First.pdf">First.pdf</a>
        </div>
        <div data-type="attachment"
          data-attachment-url="/api/files/file-2/Second.pdf"
          data-attachment-name="Second.pdf"
          data-attachment-mime="application/pdf"
          data-attachment-size="2048"
          data-attachment-id="file-2">
          <a href="/api/files/file-2/Second.pdf">Second.pdf</a>
        </div>
        """

        let links = AttachmentExtractor.extractLinks(fromHTML: html)

        #expect(links.count == 2)
        #expect(links[0].id == "file-1")
        #expect(links[0].fileName == "First.pdf")
        #expect(links[0].fileSize == 1_024)
        #expect(links[1].id == "file-2")
        #expect(links[1].fileName == "Second.pdf")
        #expect(links[1].fileSize == 2_048)
    }

    @Test func attachmentExtractionDeduplicatesHTMLLinksByAttachmentID() {
        let html = """
        <a href="/api/files/file-1/Archive%20Plan.pdf">Archive Plan.pdf</a>
        <a href="/api/files/file-1/Archive%20Plan%20Copy.pdf">Archive Plan Copy.pdf</a>
        """

        let links = AttachmentExtractor.extractLinks(fromHTML: html)

        #expect(links.count == 1)
        #expect(links[0].id == "file-1")
    }

    @Test func attachmentExtractionIgnoresMalformedUnclosedMetadataTags() throws {
        let html = """
        <div data-attachment-id="broken"
        <a href="/api/files/file-1/Archive%20Plan.pdf">Archive Plan.pdf</a>
        """

        let link = try #require(AttachmentExtractor.extractLinks(fromHTML: html).first)

        #expect(link.id == "file-1")
        #expect(link.fileName == "Archive Plan.pdf")
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

    @Test func attachmentExtractionDeduplicatesProseMirrorLinksByAttachmentID() {
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "attachment",
                attrs: [
                    "attachmentId": .string("file-1"),
                    "url": .string("/api/files/file-1/Archive%20Plan.pdf"),
                    "name": .string("Archive Plan.pdf")
                ]
            ),
            ProseMirrorNode(
                type: "attachment",
                attrs: [
                    "attachmentId": .string("file-1"),
                    "url": .string("/api/files/file-1/Archive%20Plan%20Copy.pdf"),
                    "name": .string("Archive Plan Copy.pdf")
                ]
            )
        ])

        let links = AttachmentExtractor.extractLinks(from: document)

        #expect(links.count == 1)
        #expect(links[0].id == "file-1")
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
