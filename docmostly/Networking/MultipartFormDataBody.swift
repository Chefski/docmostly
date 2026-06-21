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

nonisolated enum MultipartFormDataWriterError: Error, Equatable, Sendable {
    case invalidHeaderValue
}

nonisolated enum MultipartFormDataWriter {
    static func writeBody(
        fields: [MultipartFormDataField],
        file: MultipartFormDataFile,
        boundary: String = "DocmostlyBoundary-\(UUID().uuidString)",
        temporaryDirectory: URL = .temporaryDirectory
    ) throws -> MultipartFormDataBody {
        let safeBoundary = try escapedHeaderValue(boundary)
        let bodyURL = temporaryDirectory.appending(path: "\(UUID().uuidString).multipart")
        var completed = false

        defer {
            if completed == false {
                try? FileManager.default.removeItem(at: bodyURL)
            }
        }

        _ = FileManager.default.createFile(atPath: bodyURL.path(), contents: nil)
        let output = try FileHandle(forWritingTo: bodyURL)
        defer {
            try? output.close()
        }

        do {
            for field in fields {
                try output.writeString("--\(safeBoundary)\r\n")
                try output.writeString(
                    "Content-Disposition: form-data; name=\"\(try escaped(field.name))\"\r\n\r\n"
                )
                try output.writeString("\(field.value)\r\n")
            }

            try output.writeString("--\(safeBoundary)\r\n")
            let fileDisposition = "Content-Disposition: form-data; " +
                "name=\"\(try escaped(file.fieldName))\"; " +
                "filename=\"\(try escaped(file.fileName))\"\r\n"
            try output.writeString(fileDisposition)
            try output.writeString("Content-Type: \(try escapedHeaderValue(file.mimeType))\r\n\r\n")
            try appendFile(file.fileURL, to: output)
            try output.writeString("\r\n")
            try output.writeString("--\(safeBoundary)--\r\n")
        } catch {
            try? output.close()
            throw error
        }

        let contentLength = try output.seekToEnd()
        completed = true
        return MultipartFormDataBody(boundary: safeBoundary, fileURL: bodyURL, contentLength: contentLength)
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

    private static func escaped(_ value: String) throws -> String {
        try escapedHeaderValue(value)
            .replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
    }

    private static func escapedHeaderValue(_ value: String) throws -> String {
        guard value.unicodeScalars.allSatisfy({ scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F
        }) else {
            throw MultipartFormDataWriterError.invalidHeaderValue
        }

        return value
    }
}

private extension FileHandle {
    nonisolated func writeString(_ value: String) throws {
        try write(contentsOf: Data(value.utf8))
    }
}
