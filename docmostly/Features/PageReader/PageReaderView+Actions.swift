import SwiftUI
import UniformTypeIdentifiers

extension PageReaderView {
    func beginAttachmentImport(_ importKind: NativeEditorAttachmentImportKind) {
        attachmentImportKind = importKind
        attachmentUploadErrorMessage = nil
        isShowingAttachmentImporter = true
    }

    func beginMentionSearch() {
        isShowingMentionPicker = true
    }

    func showEmojiPicker() {
        guard readerMode == .edit, editorViewModel?.canEdit == true else { return }
        isShowingEmojiPicker = true
    }

    func applyEditorCommand(_ command: NativeEditorCommand) {
        guard command.requiresServerBackedBaseCreation else {
            editorViewModel?.applySlashCommand(command)
            return
        }

        Task {
            guard let editorViewModel else { return }
            await editorViewModel.applyServerBackedBaseSlashCommand(command) { parentPageID, template in
                let base = try await appState.createBase(parentPageId: parentPageID, template: template)
                return base.id
            }
        }
    }

    func handleAttachmentImport(_ result: Result<[URL], any Error>) {
        guard let importKind = attachmentImportKind else { return }
        attachmentImportKind = nil

        do {
            let fileURLs = try result.get()
            guard fileURLs.isEmpty == false else { return }
            uploadImportedAttachments(fileURLs: fileURLs, importKind: importKind)
        } catch {
            attachmentUploadErrorMessage = error.localizedDescription
        }
    }

    func uploadImportedAttachment(fileURL: URL, importKind: NativeEditorAttachmentImportKind) {
        uploadImportedAttachments(fileURLs: [fileURL], importKind: importKind)
    }

    func uploadImportedAttachments(fileURLs: [URL], importKind: NativeEditorAttachmentImportKind) {
        guard fileURLs.isEmpty == false else { return }

        Task {
            guard let editorViewModel else { return }

            isUploadingAttachment = true
            attachmentUploadErrorMessage = nil
            defer {
                isUploadingAttachment = false
            }

            var scopedFileURLs: [URL] = []
            defer {
                for fileURL in scopedFileURLs.reversed() {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            var uploadedAttachments: [(attachment: DocmostAttachment, sourceFileURL: URL?)] = []
            var uploadErrorMessage: String?

            for fileURL in fileURLs {
                if fileURL.startAccessingSecurityScopedResource() {
                    scopedFileURLs.append(fileURL)
                }

                do {
                    let attachment = try await appState.uploadAttachment(
                        fileURL: fileURL,
                        pageId: editorViewModel.currentPageID
                    )
                    uploadedAttachments.append((attachment: attachment, sourceFileURL: fileURL))
                } catch {
                    uploadErrorMessage = error.localizedDescription
                }
            }

            guard uploadedAttachments.isEmpty == false else {
                attachmentUploadErrorMessage = uploadErrorMessage
                return
            }

            await editorViewModel.insertUploadedAttachments(uploadedAttachments, as: importKind)

            if await editorViewModel.save(appState: appState) {
                await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
                attachmentUploadErrorMessage = uploadErrorMessage
            } else if let saveErrorMessage = editorViewModel.saveErrorMessage {
                attachmentUploadErrorMessage = saveErrorMessage
            } else if let uploadErrorMessage {
                attachmentUploadErrorMessage = uploadErrorMessage
            }
        }
    }

    func updateEditorFocus(_ focus: NativeEditorFocus?) {
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

    var attachmentUploadFailedBinding: Binding<Bool> {
        Binding {
            attachmentUploadErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                attachmentUploadErrorMessage = nil
            }
        }
    }

    var attachmentAllowedContentTypes: [UTType] {
        attachmentImportKind?.allowedContentTypes ?? NativeEditorAttachmentImportKind.file.allowedContentTypes
    }

    var inlineCommentFailedBinding: Binding<Bool> {
        Binding {
            inlineCommentErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                inlineCommentErrorMessage = nil
            }
        }
    }

    var pageActionFailedBinding: Binding<Bool> {
        Binding {
            pageActionErrorMessage != nil
        } set: { isPresented in
            if isPresented == false {
                pageActionErrorMessage = nil
            }
        }
    }

    func selectBreadcrumb(_ page: DocmostPage) {
        appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
    }

    func toggleFavorite() {
        guard let editorViewModel else { return }

        Task {
            await viewModel.toggleFavorite(pageID: editorViewModel.currentPageID, appState: appState)
            pageActionErrorMessage = viewModel.engagementErrorMessage
            viewModel.engagementErrorMessage = nil
        }
    }

    func toggleWatch() {
        guard let editorViewModel else { return }

        Task {
            await viewModel.toggleWatch(pageID: editorViewModel.currentPageID, appState: appState)
            pageActionErrorMessage = viewModel.engagementErrorMessage
            viewModel.engagementErrorMessage = nil
        }
    }

    func showDetails() {
        toggleSupplementaryPanel(.details)
    }

    func showComments() {
        toggleSupplementaryPanel(.comments)
    }

    func showTableOfContents() {
        toggleSupplementaryPanel(.tableOfContents)
    }

    func showAttachments() {
        toggleSupplementaryPanel(.attachments)
    }

    func showSharing() {
        toggleSupplementaryPanel(.sharing)
    }

    func loadSharingState() async {
        guard let editorViewModel else { return }

        await viewModel.loadSharingState(pageID: editorViewModel.currentPageID, appState: appState)
        if let errorMessage = viewModel.sharingErrorMessage {
            pageActionErrorMessage = errorMessage
            viewModel.sharingErrorMessage = nil
        }
    }

    func toggleSupplementaryPanel(_ panel: PageReaderPanel) {
        activePanel = activePanel == panel ? nil : panel
    }

    func closeSupplementaryPanel() {
        activePanel = nil
    }

    func selectHeading(_ item: PageReaderTableOfContentsItem) {
        #if !os(macOS)
        closeSupplementaryPanel()
        #endif
        scrollPosition.scrollTo(id: item.id, anchor: .top)
    }

    var tableOfContentsItems: [PageReaderTableOfContentsItem] {
        guard let editorViewModel else { return [] }
        return PageReaderTableOfContentsItem.items(in: editorViewModel.document)
    }

    var activePanelIsPresented: Binding<Bool> {
        Binding {
            activePanel != nil
        } set: { isPresented in
            if isPresented == false {
                activePanel = nil
            }
        }
    }

    var pageShareURL: URL? {
        guard let editorViewModel, let baseURL = URL(string: appState.serverURLString) else {
            return nil
        }

        let pageSlug = PageSlugBuilder.slug(slugId: editorViewModel.currentPageSlugID, title: editorViewModel.title)
        if let spaceSlug = currentSpaceSlug {
            return baseURL
                .appending(path: "s")
                .appending(path: spaceSlug)
                .appending(path: "p")
                .appending(path: pageSlug)
        }

        return baseURL
            .appending(path: "p")
            .appending(path: pageSlug)
    }

    var publicShareURL: URL? {
        guard
            let editorViewModel,
            let key = viewModel.pageShare?.key,
            let baseURL = URL(string: appState.serverURLString)
        else {
            return nil
        }

        let pageSlug = PageSlugBuilder.slug(slugId: editorViewModel.currentPageSlugID, title: editorViewModel.title)
        return baseURL
            .appending(path: "share")
            .appending(path: key)
            .appending(path: "p")
            .appending(path: pageSlug)
    }

    var workspaceSharingDisabled: Bool {
        appState.currentUser?.workspace.settings?.sharing?.disabled == true
    }

    var spaceSharingDisabled: Bool {
        guard let editorViewModel, let currentSpaceID = editorViewModel.currentSpaceID else { return false }
        return appState.spaces.first(where: { $0.id == currentSpaceID })?.settings?.sharing?.disabled == true
    }

    func setPublicSharing(_ isEnabled: Bool) async {
        guard let editorViewModel else { return }

        await viewModel.setPublicSharing(isEnabled, pageID: editorViewModel.currentPageID, appState: appState)
        if let errorMessage = viewModel.sharingErrorMessage {
            pageActionErrorMessage = errorMessage
            viewModel.sharingErrorMessage = nil
        }
    }

    func updateShareOptions(includeSubPages: Bool?, searchIndexing: Bool?) async {
        guard let editorViewModel else { return }

        await viewModel.updateShareOptions(
            pageID: editorViewModel.currentPageID,
            includeSubPages: includeSubPages,
            searchIndexing: searchIndexing,
            appState: appState
        )
        if let errorMessage = viewModel.sharingErrorMessage {
            pageActionErrorMessage = errorMessage
            viewModel.sharingErrorMessage = nil
        }
    }

    var pageNavigationTitle: String {
        if let title = editorViewModel?.title, title.isEmpty == false {
            return title
        }

        return initialTitle ?? "Page"
    }

    var navigationChromeTitle: String {
        #if os(iOS)
        ""
        #else
        pageNavigationTitle
        #endif
    }

    var currentSpaceSlug: String? {
        guard let editorViewModel else { return nil }

        if let currentSpaceID = editorViewModel.currentSpaceID,
           let space = appState.spaces.first(where: { $0.id == currentSpaceID }) {
            return space.slug
        }

        return viewModel.breadcrumbs.compactMap { $0.space?.slug }.first
    }

    func copyPageLink() {
        guard let pageShareURL else {
            pageActionErrorMessage = "Page link is unavailable."
            return
        }

        NativeEditorClipboard.write(pageShareURL.absoluteString)
    }

    func copyPageMarkdown() {
        guard let editorViewModel else { return }

        let title = editorViewModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let markdown = editorViewModel.markdownForDocument()
        NativeEditorClipboard.write("# \(title)\n\n\(markdown)")
    }

    #if os(macOS)
    func openCurrentPageInNewWindow() {
        guard let editorViewModel else { return }

        openWindow(value: MacPageWindowRoute(
            pageID: editorViewModel.currentPageSlugID,
            spaceID: editorViewModel.currentSpaceID,
            title: editorViewModel.title
        ))
    }
    #endif

    func duplicateCurrentPage() {
        guard let editorViewModel else { return }

        Task {
            do {
                let page = try await appState.duplicatePage(pageId: editorViewModel.currentPageID)
                appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
            } catch {
                pageActionErrorMessage = error.localizedDescription
            }
        }
    }

    func showLabelEditor() {
        isShowingLabelEditor = true
    }

    func showMoveToSpace() {
        isShowingMoveToSpace = true
    }

    func moveCurrentPage(to targetSpaceID: String) async -> String? {
        guard let editorViewModel else {
            return "Page unavailable."
        }

        do {
            try await appState.movePageToSpace(pageId: editorViewModel.currentPageID, spaceId: targetSpaceID)
            appState.selectSpace(id: targetSpaceID)
            dismiss()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func trashCurrentPage() {
        guard let editorViewModel else { return }

        Task {
            do {
                try await appState.deletePage(pageId: editorViewModel.currentPageID)
                appState.clearSelectedPage()
                dismiss()
            } catch {
                pageActionErrorMessage = error.localizedDescription
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

    func createInlineComment(_ body: CommentBody) async throws {
        guard let editorViewModel, let inlineCommentContext else {
            throw NativeEditorInlineCommentCreationError.noSelection
        }

        let commentID: String
        let yjsSelection: NativeEditorYjsSelection?
        if let pendingInlineCommentID, pendingInlineCommentDraft == body {
            commentID = pendingInlineCommentID
            yjsSelection = pendingInlineCommentYjsSelection
        } else {
            yjsSelection = await editorViewModel.inlineCommentYjsSelection(for: inlineCommentContext)
            let comment = try await appState.addInlineComment(
                pageId: editorViewModel.currentPageID,
                body: body,
                selectedText: inlineCommentContext.selectedText,
                yjsSelection: yjsSelection
            )
            viewModel.applyCreatedComment(comment)
            commentID = comment.id
            pendingInlineCommentID = comment.id
            pendingInlineCommentDraft = body
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

    func removeInlineComment(commentID: String) async {
        guard let editorViewModel else { return }

        editorViewModel.removeInlineComment(commentID: commentID)
        if editorViewModel.canSave {
            _ = await editorViewModel.save(appState: appState)
        }
    }
}
