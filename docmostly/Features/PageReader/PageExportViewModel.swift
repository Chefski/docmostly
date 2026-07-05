import Foundation
import Observation

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
        exportedFile = nil
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
