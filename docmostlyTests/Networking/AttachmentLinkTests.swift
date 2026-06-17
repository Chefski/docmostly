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
}
