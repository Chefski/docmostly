import SwiftUI
import UniformTypeIdentifiers

struct PageReaderView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel = PageReaderViewModel()
    @State var editorViewModel: NativeRichEditorViewModel?
    @State var realtimeEventClient = NativeEditorRealtimeEventClient()
    @State var collaborationPresenceClient = NativeEditorCollaborationPresenceClient()
    @State private var attachmentImportKind: NativeEditorAttachmentImportKind?
    @State private var isShowingAttachmentImporter = false
    @State private var isShowingMentionPicker = false
    @State private var isShowingInlineCommentComposer = false
    @State private var isUploadingAttachment = false
    @State private var attachmentUploadErrorMessage: String?
    @State private var inlineCommentContext: NativeEditorInlineCommentContext?
    @State private var inlineCommentErrorMessage: String?
    @State private var pageActionErrorMessage: String?
    @State private var isConfirmingPageTrash = false
    @State private var isShowingLabelEditor = false
    @State private var isShowingMoveToSpace = false
    @State private var pendingInlineCommentID: String?
    @State private var pendingInlineCommentDraft: String?
    @State private var pendingInlineCommentYjsSelection: NativeEditorYjsSelection?
    @FocusState private var editorFocusedField: NativeEditorFocus?

    let pageID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let editorViewModel {
                    if editorViewModel.isLoading {
                        LoadingStateView(title: "Loading page")
                            .frame(minHeight: 360)
                    } else if let errorMessage = editorViewModel.errorMessage {
                        ErrorStateView(title: "Page unavailable", message: errorMessage, retry: retry)
                    } else {
                        PageReaderMetadataView(
                            breadcrumbs: viewModel.breadcrumbs,
                            labels: viewModel.labels,
                            selectPage: selectBreadcrumb
                        )
                        NativeEditorBodyView(viewModel: editorViewModel, focusedField: $editorFocusedField)
                        AttachmentLinksView(
                            links: viewModel.attachmentLinks,
                            serverURLString: appState.serverURLString
                        )
                        CommentsSectionView(
                            viewModel: viewModel,
                            pageID: editorViewModel.currentPageID
                        ) { commentID, isResolved in
                            await markInlineCommentResolved(commentID: commentID, isResolved: isResolved)
                        }
                    }
                } else {
                    LoadingStateView(title: "Loading page")
                        .frame(minHeight: 360)
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(editorViewModel?.title.isEmpty == false ? editorViewModel?.title ?? "Page" : "Page")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise", action: retry)

                if let editorViewModel, editorViewModel.errorMessage == nil {
                    Button(
                        viewModel.isFavoritePage ? "Remove Favorite" : "Add Favorite",
                        systemImage: viewModel.isFavoritePage ? "star.fill" : "star",
                        action: toggleFavorite
                    )
                    .disabled(viewModel.isTogglingFavorite)

                    Button(
                        viewModel.isWatchingPage == true ? "Unwatch Page" : "Watch Page",
                        systemImage: viewModel.isWatchingPage == true ? "eye.fill" : "eye",
                        action: toggleWatch
                    )
                    .disabled(viewModel.isTogglingWatch)

                    Menu("Page Actions", systemImage: "ellipsis.circle") {
                        if editorViewModel.canEdit {
                            Button("Edit Labels", systemImage: "tag", action: showLabelEditor)
                        }
                        if editorViewModel.currentSpaceID != nil {
                            Button("Move to Space", systemImage: "folder", action: showMoveToSpace)
                        }
                        Button("Duplicate", systemImage: "doc.on.doc", action: duplicateCurrentPage)
                        Button("Move to Trash", systemImage: "trash", role: .destructive) {
                            isConfirmingPageTrash = true
                        }
                    }
                }

                if let editorViewModel, editorViewModel.isSaving {
                    ProgressView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let editorViewModel, editorViewModel.isEditing, editorViewModel.canEdit {
                VStack(spacing: 6) {
                    if isUploadingAttachment {
                        ProgressView("Uploading attachment")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    }

                    NativeEditorToolbar(
                        viewModel: editorViewModel,
                        isUploadingAttachment: isUploadingAttachment,
                        importAttachment: beginAttachmentImport,
                        showMentionPicker: beginMentionSearch,
                        showInlineCommentComposer: beginInlineComment
                    ) {
                        editorFocusedField = nil
                        editorViewModel.clearFocus()
                        autosaveInlineEdits()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingAttachmentImporter,
            allowedContentTypes: attachmentAllowedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleAttachmentImport
        )
        .alert("Attachment Upload Failed", isPresented: attachmentUploadFailedBinding) {
            Button("OK", role: .cancel) {
                attachmentUploadErrorMessage = nil
            }
        } message: {
            Text(attachmentUploadErrorMessage ?? "")
        }
        .alert("Inline Comment", isPresented: inlineCommentFailedBinding) {
            Button("OK", role: .cancel) {
                inlineCommentErrorMessage = nil
            }
        } message: {
            Text(inlineCommentErrorMessage ?? "")
        }
        .alert("Page Action Failed", isPresented: pageActionFailedBinding) {
            Button("OK", role: .cancel) {
                pageActionErrorMessage = nil
            }
        } message: {
            Text(pageActionErrorMessage ?? "")
        }
        .confirmationDialog("Move this page to trash?", isPresented: $isConfirmingPageTrash) {
            Button("Move to Trash", role: .destructive, action: trashCurrentPage)
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isShowingMentionPicker) {
            if let editorViewModel {
                NativeEditorMentionPickerView(viewModel: editorViewModel)
            }
        }
        .sheet(isPresented: $isShowingInlineCommentComposer) {
            if let inlineCommentContext {
                NativeEditorInlineCommentComposerView(
                    selectedText: inlineCommentContext.selectedText,
                    submit: createInlineComment
                )
            }
        }
        .sheet(isPresented: $isShowingLabelEditor) {
            if let editorViewModel {
                PageLabelEditorSheet(pageID: editorViewModel.currentPageID, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $isShowingMoveToSpace) {
            if let editorViewModel, let currentSpaceID = editorViewModel.currentSpaceID {
                PageReaderMoveToSpaceSheet(
                    pageTitle: editorViewModel.title,
                    currentSpaceID: currentSpaceID,
                    spaces: appState.spaces
                ) { targetSpaceID in
                    await moveCurrentPage(to: targetSpaceID)
                }
            }
        }
        .task(id: pageID) {
            await loadNativePage()
        }
        .task(id: editorViewModel?.currentPageID) {
            await monitorRemotePageChanges()
        }
        .task(id: editorViewModel?.currentPageID) {
            await monitorRealtimeEvents()
        }
        .task(id: editorViewModel?.currentPageID) {
            await monitorCollaborationPresence()
        }
        .task(id: editorViewModel?.currentPageID) {
            await monitorCRDTDocumentSnapshots()
        }
        .onChange(of: editorFocusedField) { _, newValue in
            updateEditorFocus(newValue)
        }
        .onChange(of: isShowingInlineCommentComposer) { _, isShowing in
            if isShowing == false {
                inlineCommentContext = nil
                pendingInlineCommentID = nil
                pendingInlineCommentDraft = nil
            }
        }
        .onDisappear {
            autosaveInlineEdits()
        }
    }

    private func retry() {
        Task {
            await loadNativePage()
        }
    }

    private func loadNativePage() async {
        editorFocusedField = nil
        editorViewModel = nil
        let editorViewModel = NativeRichEditorViewModel(pageID: pageID)

        await editorViewModel.load(appState: appState)
        if editorViewModel.errorMessage == nil {
            await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
                to: editorViewModel,
                appState: appState
            )
            self.editorViewModel = editorViewModel
            await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
        } else {
            self.editorViewModel = editorViewModel
        }
    }

    private func autosaveInlineEdits() {
        guard let editorViewModel, editorViewModel.canSave else { return }

        Task {
            if await editorViewModel.save(appState: appState) {
                await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
            }
        }
    }

    private func beginAttachmentImport(_ importKind: NativeEditorAttachmentImportKind) {
        attachmentImportKind = importKind
        attachmentUploadErrorMessage = nil
        isShowingAttachmentImporter = true
    }

    private func beginMentionSearch() {
        isShowingMentionPicker = true
    }

    private func handleAttachmentImport(_ result: Result<[URL], any Error>) {
        guard let importKind = attachmentImportKind else { return }
        attachmentImportKind = nil

        do {
            guard let fileURL = try result.get().first else { return }
            uploadImportedAttachment(fileURL: fileURL, importKind: importKind)
        } catch {
            attachmentUploadErrorMessage = error.localizedDescription
        }
    }

    private func uploadImportedAttachment(fileURL: URL, importKind: NativeEditorAttachmentImportKind) {
        Task {
            guard let editorViewModel else { return }

            isUploadingAttachment = true
            attachmentUploadErrorMessage = nil
            defer {
                isUploadingAttachment = false
            }

            let didStartScopedAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if didStartScopedAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let attachment = try await appState.uploadAttachment(
                    fileURL: fileURL,
                    pageId: editorViewModel.currentPageID
                )
                editorViewModel.insertUploadedAttachment(
                    attachment,
                    as: importKind,
                    sourceFileURL: fileURL
                )

                if await editorViewModel.save(appState: appState) {
                    await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
                } else if let saveErrorMessage = editorViewModel.saveErrorMessage {
                    attachmentUploadErrorMessage = saveErrorMessage
                }
            } catch {
                attachmentUploadErrorMessage = error.localizedDescription
            }
        }
    }

    private func updateEditorFocus(_ focus: NativeEditorFocus?) {
        guard let editorViewModel else { return }

        switch focus {
        case .title:
            editorViewModel.focusTitle()
        case .block(let blockID):
            editorViewModel.focus(blockID: blockID)
        case nil:
            editorViewModel.clearFocus()
            autosaveInlineEdits()
        }
    }

    private var attachmentUploadFailedBinding: Binding<Bool> {
        Binding {
            attachmentUploadErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                attachmentUploadErrorMessage = nil
            }
        }
    }

    private var attachmentAllowedContentTypes: [UTType] {
        attachmentImportKind?.allowedContentTypes ?? NativeEditorAttachmentImportKind.file.allowedContentTypes
    }

    private var pageActionFailedBinding: Binding<Bool> {
        Binding {
            pageActionErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                pageActionErrorMessage = nil
            }
        }
    }

    private func selectBreadcrumb(_ page: DocmostPage) {
        appState.selectedSpaceID = page.spaceId
        appState.selectedPageID = page.slugId
    }

    private func toggleFavorite() {
        guard let editorViewModel else { return }

        Task {
            await viewModel.toggleFavorite(pageID: editorViewModel.currentPageID, appState: appState)
            pageActionErrorMessage = viewModel.engagementErrorMessage
            viewModel.engagementErrorMessage = nil
        }
    }

    private func toggleWatch() {
        guard let editorViewModel else { return }

        Task {
            await viewModel.toggleWatch(pageID: editorViewModel.currentPageID, appState: appState)
            pageActionErrorMessage = viewModel.engagementErrorMessage
            viewModel.engagementErrorMessage = nil
        }
    }

    private func duplicateCurrentPage() {
        guard let editorViewModel else { return }

        Task {
            do {
                let page = try await appState.duplicatePage(pageId: editorViewModel.currentPageID)
                appState.selectedSpaceID = page.spaceId
                appState.selectedPageID = page.slugId
            } catch {
                pageActionErrorMessage = error.localizedDescription
            }
        }
    }

    private func showLabelEditor() {
        isShowingLabelEditor = true
    }

    private func showMoveToSpace() {
        isShowingMoveToSpace = true
    }

    private func moveCurrentPage(to targetSpaceID: String) async -> String? {
        guard let editorViewModel else {
            return "Page unavailable."
        }

        do {
            try await appState.movePageToSpace(pageId: editorViewModel.currentPageID, spaceId: targetSpaceID)
            appState.selectedSpaceID = targetSpaceID
            appState.selectedPageID = nil
            dismiss()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func trashCurrentPage() {
        guard let editorViewModel else { return }

        Task {
            do {
                try await appState.deletePage(pageId: editorViewModel.currentPageID)
                appState.selectedPageID = nil
                dismiss()
            } catch {
                pageActionErrorMessage = error.localizedDescription
            }
        }
    }
}

private extension PageReaderView {
    func monitorRemotePageChanges() async {
        guard let editorViewModel else { return }
        guard editorViewModel.usesCRDTDocumentEngine == false else { return }
        editorViewModel.realtimeStatus = .connecting

        do {
            _ = try appState.collaborationWebSocketURL()
            _ = try await appState.loadCollaborationToken()
        } catch {
            editorViewModel.realtimeStatus = .unsupported(error.localizedDescription)
        }

        while Task.isCancelled == false {
            guard editorViewModel.usesCRDTDocumentEngine == false else { return }

            do {
                let page = try await appState.loadEditablePage(idOrSlugId: editorViewModel.currentPageID)
                editorViewModel.handleRemotePageSnapshot(page)
                try await Task.sleep(for: .seconds(4))
            } catch {
                editorViewModel.realtimeStatus = .failed(error.localizedDescription)
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

}

private extension PageReaderView {
    var inlineCommentFailedBinding: Binding<Bool> {
        Binding {
            inlineCommentErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                inlineCommentErrorMessage = nil
            }
        }
    }

    func beginInlineComment() {
        guard let context = editorViewModel?.activeInlineCommentContext else {
            inlineCommentErrorMessage = NativeEditorInlineCommentCreationError.noSelection.localizedDescription
            return
        }

        inlineCommentErrorMessage = nil
        inlineCommentContext = context
        pendingInlineCommentID = nil
        pendingInlineCommentDraft = nil
        pendingInlineCommentYjsSelection = nil
        isShowingInlineCommentComposer = true
    }

    func createInlineComment(_ text: String) async throws {
        guard let editorViewModel, let inlineCommentContext else {
            throw NativeEditorInlineCommentCreationError.noSelection
        }

        let commentID: String
        let yjsSelection: NativeEditorYjsSelection?
        if let pendingInlineCommentID, pendingInlineCommentDraft == text {
            commentID = pendingInlineCommentID
            yjsSelection = pendingInlineCommentYjsSelection
        } else {
            yjsSelection = await editorViewModel.inlineCommentYjsSelection(for: inlineCommentContext)
            let comment = try await appState.addInlineComment(
                pageId: editorViewModel.currentPageID,
                text: text,
                selectedText: inlineCommentContext.selectedText,
                yjsSelection: yjsSelection
            )
            viewModel.applyCreatedComment(comment)
            commentID = comment.id
            pendingInlineCommentID = comment.id
            pendingInlineCommentDraft = text
            pendingInlineCommentYjsSelection = yjsSelection
        }

        let didApplyLocalMark = editorViewModel.applyInlineCommentFallback(
            commentID: commentID,
            to: inlineCommentContext,
            yjsSelection: yjsSelection
        )

        if didApplyLocalMark {
            guard await editorViewModel.save(appState: appState) else {
                let message = editorViewModel.saveErrorMessage ??
                    "Comment was created, but the page update did not save."
                throw NativeEditorInlineCommentCreationError.saveFailed(message)
            }
        }

        pendingInlineCommentID = nil
        pendingInlineCommentDraft = nil
        pendingInlineCommentYjsSelection = nil
        await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
    }

    func markInlineCommentResolved(commentID: String, isResolved: Bool) async {
        guard let editorViewModel else { return }

        editorViewModel.setInlineCommentResolved(commentID: commentID, isResolved: isResolved)
        if editorViewModel.canSave {
            _ = await editorViewModel.save(appState: appState)
        }
    }
}
