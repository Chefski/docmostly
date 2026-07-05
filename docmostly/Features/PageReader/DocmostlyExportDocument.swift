import Foundation
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct DocmostlyExportDocument: FileDocument, Equatable, Sendable {
    static var readableContentTypes: [UTType] { [.data] }

    let data: Data
    let fileName: String
    let contentType: UTType

    init(exportFile: DocmostPageExportFile) {
        data = exportFile.data
        fileName = exportFile.fileName
        if let mimeType = exportFile.mimeType, let type = UTType(mimeType: mimeType) {
            contentType = type
        } else if let type = UTType(filenameExtension: (exportFile.fileName as NSString).pathExtension) {
            contentType = type
        } else {
            contentType = .data
        }
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        fileName = "docmost-page"
        contentType = configuration.contentType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
