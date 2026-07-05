import Foundation
import Observation

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
            } catch is CancellationError {
                return
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
