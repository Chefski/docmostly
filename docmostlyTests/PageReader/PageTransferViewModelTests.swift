import Foundation
import Testing
import UniformTypeIdentifiers
@testable import docmostly

@MainActor
struct PageTransferViewModelTests {
    @Test func importFilterOnlyAllowsServerBackedMarkdownAndHTML() {
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/page.md")))
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/page.markdown")))
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/page.html")))
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/page.htm")))
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/page.docx")) == false)
        #expect(PageImportViewModel.isSupportedServerImport(URL(filePath: "/tmp/pages.zip")) == false)
    }

    @Test func exportDocumentPreservesDataAndContentType() throws {
        let exportFile = DocmostPageExportFile(
            data: Data("<h1>Roadmap</h1>".utf8),
            fileName: "Roadmap.html",
            mimeType: "text/html"
        )

        let document = DocmostlyExportDocument(exportFile: exportFile)
        #expect(document.fileName == "Roadmap.html")
        #expect(document.contentType.preferredMIMEType == "text/html")
        #expect(document.data == exportFile.data)
    }

    @Test func historyRestoreConfirmationStartsEmptyAndRequiresSelection() {
        let viewModel = PageHistoryViewModel()

        #expect(viewModel.canRequestRestoreConfirmation == false)
        viewModel.requestRestoreConfirmation()
        #expect(viewModel.pendingRestoreVersion == nil)
    }
}
