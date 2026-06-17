import Foundation
import Testing
@testable import docmostly

struct MultipartFormDataBodyTests {
    @Test func writesFieldsAndFileIntoMultipartBody() throws {
        let sourceURL = URL.temporaryDirectory.appending(path: "docmostly-upload-source.txt")
        try "hello attachment".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }

        let body = try MultipartFormDataWriter.writeBody(
            fields: [
                MultipartFormDataField(name: "pageId", value: "page-1"),
                MultipartFormDataField(name: "attachmentId", value: "attachment-1")
            ],
            file: MultipartFormDataFile(
                fieldName: "file",
                fileURL: sourceURL,
                fileName: "Report \"Q2\".txt",
                mimeType: "text/plain"
            ),
            boundary: "Boundary",
            temporaryDirectory: .temporaryDirectory
        )
        defer {
            try? FileManager.default.removeItem(at: body.fileURL)
        }

        let multipart = try String(contentsOf: body.fileURL, encoding: .utf8)
        #expect(multipart.contains("--Boundary\r\n"))
        #expect(multipart.contains("Content-Disposition: form-data; name=\"pageId\""))
        #expect(multipart.contains("page-1\r\n"))
        #expect(multipart.contains("Content-Disposition: form-data; name=\"attachmentId\""))
        #expect(multipart.contains("filename=\"Report \\\"Q2\\\".txt\""))
        #expect(multipart.contains("Content-Type: text/plain\r\n\r\nhello attachment"))
        #expect(multipart.hasSuffix("--Boundary--\r\n"))
        #expect(body.contentLength > 0)
    }
}
