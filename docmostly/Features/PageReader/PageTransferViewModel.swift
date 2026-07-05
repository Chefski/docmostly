import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class PageExportViewModel {
    var format: DocmostPageExportFormat = .markdown
    var includeChildren = false
    private(set) var isExporting = false
    var errorMessage: String?
    var exportedFile: DocmostlyExportDocument?

    func export(pageID: String, appState: AppState) async {
        guard isExporting == false else { return }

        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let file = try await appState.exportPage(
                pageId: pageID,
                format: format,
                includeChildren: includeChildren
            )
            exportedFile = DocmostlyExportDocument(exportFile: file)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
@Observable
final class PageImportViewModel {
    private(set) var importedPages: [DocmostPage] = []
    private(set) var isImporting = false
    var errorMessage: String?

    var canImport: Bool {
        isImporting == false
    }

    func importFiles(_ fileURLs: [URL], spaceID: String, appState: AppState) async {
        guard isImporting == false, fileURLs.isEmpty == false else { return }

        isImporting = true
        errorMessage = nil
        importedPages = []
        defer { isImporting = false }

        var failures: [String] = []
        for fileURL in fileURLs where Task.isCancelled == false {
            guard Self.isSupportedServerImport(fileURL) else {
                failures.append("\(fileURL.lastPathComponent) is not a supported server import format.")
                continue
            }

            do {
                let page = try await appState.importPage(fileURL: fileURL, spaceId: spaceID)
                importedPages.append(page)
            } catch {
                failures.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if failures.isEmpty == false {
            errorMessage = failures.joined(separator: "\n")
        }
    }

    static func isSupportedServerImport(_ fileURL: URL) -> Bool {
        switch fileURL.pathExtension.lowercased() {
        case "md", "markdown", "html", "htm":
            true
        default:
            false
        }
    }
}

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

nonisolated enum DocmostlyPageImportTypes {
    static let markdown = UTType(filenameExtension: "md") ?? .plainText
    static let markdownLong = UTType(filenameExtension: "markdown") ?? .plainText
    static let supported: [UTType] = [markdown, markdownLong, .html]
}
