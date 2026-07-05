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

    @Test func failedHistoryRestoreRollsEditorBackToPreRestoreSnapshot() async {
        let engine = FailingHistoryRestoreCRDTDocumentEngine()
        let currentDocument = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Current content"), alignment: .left)
        ])
        let historicalDocument = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Historical content"), alignment: .left)
        ])
        let editorViewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Current title",
            crdtDocumentEngine: engine
        )
        editorViewModel.document = currentDocument
        editorViewModel.lastSavedTitle = editorViewModel.title
        editorViewModel.lastSavedDocument = currentDocument
        editorViewModel.resetEditingHistory()
        editorViewModel.isDirty = false

        let historyViewModel = PageHistoryViewModel()
        historyViewModel.pendingRestoreVersion = DocmostPageHistory(
            id: "history-1",
            pageId: "page-1",
            title: "Historical title",
            content: historicalDocument.proseMirrorDocument,
            slug: nil,
            icon: nil,
            coverPhoto: nil,
            version: 3,
            lastUpdatedById: nil,
            workspaceId: nil,
            createdAt: nil,
            updatedAt: nil,
            lastUpdatedBy: nil,
            contributors: nil
        )

        let didRestore = await historyViewModel.restoreConfirmed(
            editorViewModel: editorViewModel,
            appState: AppState()
        )

        #expect(didRestore == false)
        #expect(editorViewModel.title == "Current title")
        #expect(editorViewModel.document == currentDocument)
        #expect(editorViewModel.isDirty == false)
        #expect(
            historyViewModel.restoreErrorMessage ==
                APIError.connectionFailed("Restore save failed.").localizedDescription
        )
    }
}

@MainActor
private final class FailingHistoryRestoreCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        throw APIError.connectionFailed("Restore save failed.")
    }
}
