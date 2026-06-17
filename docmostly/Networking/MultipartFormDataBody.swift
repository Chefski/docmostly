import Foundation

nonisolated struct MultipartFormDataField: Equatable, Sendable {
    let name: String
    let value: String
}

nonisolated struct MultipartFormDataFile: Equatable, Sendable {
    let fieldName: String
    let fileURL: URL
    let fileName: String
    let mimeType: String
}

nonisolated struct MultipartFormDataBody: Equatable, Sendable {
    let boundary: String
    let fileURL: URL
    let contentLength: UInt64
}

nonisolated enum MultipartFormDataWriter {
    static func writeBody(
        fields: [MultipartFormDataField],
        file: MultipartFormDataFile,
        boundary: String = "DocmostlyBoundary-\(UUID().uuidString)",
        temporaryDirectory: URL = .temporaryDirectory
    ) throws -> MultipartFormDataBody {
        let bodyURL = temporaryDirectory.appending(path: "\(UUID().uuidString).multipart")
        _ = FileManager.default.createFile(atPath: bodyURL.path(), contents: nil)

        let output = try FileHandle(forWritingTo: bodyURL)
        defer {
            try? output.close()
        }

        for field in fields {
            try output.writeString("--\(boundary)\r\n")
            try output.writeString(
                "Content-Disposition: form-data; name=\"\(escaped(field.name))\"\r\n\r\n"
            )
            try output.writeString("\(field.value)\r\n")
        }

        try output.writeString("--\(boundary)\r\n")
        let fileDisposition = "Content-Disposition: form-data; " +
            "name=\"\(escaped(file.fieldName))\"; " +
            "filename=\"\(escaped(file.fileName))\"\r\n"
        try output.writeString(fileDisposition)
        try output.writeString("Content-Type: \(file.mimeType)\r\n\r\n")
        try appendFile(file.fileURL, to: output)
        try output.writeString("\r\n")
        try output.writeString("--\(boundary)--\r\n")

        let contentLength = try output.seekToEnd()
        return MultipartFormDataBody(boundary: boundary, fileURL: bodyURL, contentLength: contentLength)
    }

    private static func appendFile(_ fileURL: URL, to output: FileHandle) throws {
        let input = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? input.close()
        }

        while true {
            guard let chunk = try input.read(upToCount: 1_048_576), chunk.isEmpty == false else {
                break
            }
            try output.write(contentsOf: chunk)
        }
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
    }
}

private extension FileHandle {
    nonisolated func writeString(_ value: String) throws {
        try write(contentsOf: Data(value.utf8))
    }
}
