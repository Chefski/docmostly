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
