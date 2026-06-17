import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class NativeRichEditorViewModel {
    let pageID: String
    var title: String
    var document = NativeEditorDocument()
    var isLoading = false
    var isSaving = false
    var isDirty = false
    var errorMessage: String?
    var saveErrorMessage: String?
    var activeBlockID: UUID?
    var selectedBlockID: UUID?
    var visibleBlockControlsID: UUID?
    var isTitleFocused = false
    var canUndo = false
    var canRedo = false
    var searchQuery = ""
    var replacementText = ""
    var currentSearchMatchIndex = 0
    var realtimeStatus: NativeEditorRealtimeStatus = .disconnected
    var pendingRemoteUpdate: NativeEditorRemoteUpdate?
    var activeCollaborators: [NativeEditorCollaborator] = []
    var remoteCursors: [NativeEditorRemoteCursor] = []
    var resolvedRemoteCursors: [NativeEditorResolvedRemoteCursor] = []

    @ObservationIgnored private var editablePageID: String
    @ObservationIgnored var lastSavedTitle: String
    @ObservationIgnored var lastSavedDocument = NativeEditorDocument()
    @ObservationIgnored var lastRemoteUpdatedAt: Date?
    @ObservationIgnored var pendingRemotePage: DocmostEditablePage?
    @ObservationIgnored var undoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var redoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var lastKnownSnapshot: NativeEditorHistorySnapshot?
    @ObservationIgnored var isApplyingHistory = false
    @ObservationIgnored private var crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)?

    init(
        pageID: String,
        initialTitle: String = "",
        crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)? = nil
    ) {
        self.pageID = pageID
        title = initialTitle
        editablePageID = pageID
        lastSavedTitle = initialTitle
        lastKnownSnapshot = makeHistorySnapshot()
        self.crdtDocumentEngine = crdtDocumentEngine
    }

    var isEditing: Bool {
        isTitleFocused || activeBlockID != nil
    }

    var currentPageID: String {
        editablePageID
    }

    var isShowingSlashCommands: Bool {
        activeSlashCommandQuery != nil
    }

    var slashCommandQuery: String {
        activeSlashCommandQuery ?? ""
    }

    var filteredSlashCommands: [NativeEditorCommand] {
        NativeEditorCommand.allCases.filter { command in
            command.matches(query: slashCommandQuery)
        }
    }

    var canSave: Bool {
        isDirty &&
        isLoading == false &&
        isSaving == false &&
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await appState.loadEditablePage(idOrSlugId: pageID)
            editablePageID = page.id
            title = page.title
            document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
            lastSavedTitle = title
            lastSavedDocument = document
            resetEditingHistory()
            markRemoteBaseline(updatedAt: page.updatedAt)
            isDirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(appState: AppState) async -> Bool {
        guard canSave else { return false }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        do {
            let page = try await appState.updatePage(
                pageId: editablePageID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                document: document.proseMirrorDocument
            )
            editablePageID = page.id
            title = page.title
            lastSavedTitle = title
            lastSavedDocument = document
            markRemoteBaseline(updatedAt: page.updatedAt)
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = false
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func retryLoad(appState: AppState) {
        Task {
            await load(appState: appState)
        }
    }

    func focusTitle() {
        isTitleFocused = true
        activeBlockID = nil
        selectedBlockID = nil
        visibleBlockControlsID = nil
    }

    func focus(blockID: UUID) {
        isTitleFocused = false
        activeBlockID = blockID
        selectedBlockID = nil
        visibleBlockControlsID = nil
    }

    func clearFocus() {
        isTitleFocused = false
        activeBlockID = nil
    }

    func selectBlock(_ blockID: UUID) {
        guard document.blocks.contains(where: { $0.id == blockID }) else { return }
        isTitleFocused = false
        activeBlockID = nil
        visibleBlockControlsID = blockID
        selectedBlockID = selectedBlockID == blockID ? nil : blockID
    }

    func clearBlockSelection() {
        selectedBlockID = nil
    }

    func showBlockControls(for blockID: UUID) {
        guard document.blocks.contains(where: { $0.id == blockID }) else { return }
        isTitleFocused = false
        activeBlockID = nil
        visibleBlockControlsID = blockID
    }

    func hideBlockControls() {
        visibleBlockControlsID = nil
        selectedBlockID = nil
    }

    func recalculateDirty() {
        isDirty = title != lastSavedTitle || document != lastSavedDocument
    }

    func configureCRDTDocumentEngine(_ engine: any NativeEditorCRDTDocumentEngine) {
        crdtDocumentEngine = engine
    }

    func collaborationSession() -> NativeEditorCollaborationSession {
        let documentName = "page.\(currentPageID)"
        let syncDriver = crdtDocumentEngine.map { engine in
            NativeEditorCollaborationSyncDriver(
                documentName: documentName,
                coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
            )
        }
        return NativeEditorCollaborationSession(
            documentName: documentName,
            syncDriver: syncDriver
        )
    }

    func refreshResolvedRemoteCursors() async {
        guard let crdtDocumentEngine else {
            resolvedRemoteCursors = []
            return
        }

        var resolvedCursors: [NativeEditorResolvedRemoteCursor] = []
        resolvedCursors.reserveCapacity(remoteCursors.count)

        for cursor in remoteCursors {
            if let resolvedCursor = try? await crdtDocumentEngine.resolveRemoteCursor(cursor) {
                resolvedCursors.append(resolvedCursor)
            }
        }

        resolvedRemoteCursors = resolvedCursors
    }
}

extension NativeRichEditorViewModel {
    func setActiveBlockKind(_ kind: NativeEditorBlockKind) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }
            document.blocks[index].kind = kind
        }
    }

    func applySlashCommand(_ command: NativeEditorCommand) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if let replacementBlock = command.replacementBlock(reusing: document.blocks[index].id) {
                document.blocks[index] = replacementBlock
                return
            }

            document.blocks[index].kind = command.blockKind
            if activeSlashCommandQuery != nil {
                document.blocks[index].text = AttributedString("")
                document.blocks[index].selection = AttributedTextSelection()
            }
        }
    }

    func setActiveAlignment(_ alignment: NativeEditorTextAlignment) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }
            document.blocks[index].alignment = alignment
        }
    }

    func toggleInlineMark(_ mark: NativeEditorInlineMark) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    mark.toggle(in: &attributes)
                }
                document.blocks[index].selection = selection
            } else {
                mark.toggle(in: &document.blocks[index].text)
            }
        }
    }

    func applyLink(_ urlString: String) {
        performUndoableEdit {
            guard
                let index = activeBlockIndex,
                let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                return
            }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    attributes.link = url
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = url
            }
        }
    }

    func removeLink() {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    attributes.link = nil
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = nil
            }
        }
    }

    func appendBlock() {
        performUndoableEdit {
            document.blocks.append(NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left))
            activeBlockID = document.blocks.last?.id
        }
    }

    func insertBlock(after blockID: UUID) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else {
                document.blocks.append(
                    NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
                )
                activeBlockID = document.blocks.last?.id
                return
            }

            let nextIndex = document.blocks.index(after: index)
            let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
            document.blocks.insert(block, at: nextIndex)
            activeBlockID = block.id
        }
    }

    func deleteBlock(_ blockID: UUID) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else { return }

            if document.blocks.count == 1 {
                document.blocks[0].text = AttributedString("")
                document.blocks[0].kind = .paragraph
                document.blocks[0].alignment = .left
                document.blocks[0].indentLevel = 0
            } else {
                document.blocks.remove(at: index)
            }

            if activeBlockID == blockID {
                activeBlockID = document.blocks.indices.contains(index) ?
                    document.blocks[index].id :
                    document.blocks.last?.id
            }

            if selectedBlockID == blockID {
                selectedBlockID = nil
                visibleBlockControlsID = nil
                activeBlockID = document.blocks.indices.contains(index) ?
                    document.blocks[index].id :
                    document.blocks.last?.id
            }
        }
    }

    func deleteSelectedBlock() {
        guard let selectedBlockID else { return }
        deleteBlock(selectedBlockID)
    }

    func moveBlock(_ blockID: UUID, before targetBlockID: UUID) {
        performUndoableEdit {
            guard
                blockID != targetBlockID,
                let sourceIndex = document.blocks.firstIndex(where: { $0.id == blockID }),
                document.blocks.contains(where: { $0.id == targetBlockID })
            else {
                return
            }

            let block = document.blocks.remove(at: sourceIndex)
            guard let targetIndex = document.blocks.firstIndex(where: { $0.id == targetBlockID }) else {
                document.blocks.insert(block, at: sourceIndex)
                return
            }

            document.blocks.insert(block, at: targetIndex)
        }
    }

    var activeBlockIndex: Array<NativeEditorBlock>.Index? {
        guard let activeBlockID else { return nil }
        return document.blocks.firstIndex { $0.id == activeBlockID && $0.isEditable }
    }

    private var activeSlashCommandQuery: String? {
        guard let index = activeBlockIndex else { return nil }

        let text = String(document.blocks[index].text.characters)
        guard text.first == "/", text.contains("\n") == false else {
            return nil
        }

        return String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
