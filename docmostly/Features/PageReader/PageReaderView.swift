import SwiftUI
import UniformTypeIdentifiers

struct PageReaderView: View {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @State var viewModel = PageReaderViewModel()
    @State var editorViewModel: NativeRichEditorViewModel?
    @State var pageHistoryViewModel = PageHistoryViewModel()
    @State var pageExportViewModel = PageExportViewModel()
    @State var pageImportViewModel = PageImportViewModel()
    @State var realtimeEventClient = NativeEditorRealtimeEventClient()
    @State var collaborationPresenceClient = NativeEditorCollaborationPresenceClient()
    @State var attachmentImportKind: NativeEditorAttachmentImportKind?
    @State var isShowingAttachmentImporter = false
    @State var isShowingPageHistory = false
    @State var isShowingPageExport = false
    @State var isShowingPageImport = false
    @State var isShowingMentionPicker = false
    @State var isShowingInlineCommentComposer = false
    @State var isUploadingAttachment = false
    @State var pageImportTaskID: UUID?
    @State var pageImportTask: Task<Void, Never>?
    @State var attachmentUploadErrorMessage: String?
    @State var inlineCommentContext: NativeEditorInlineCommentContext?
    @State var inlineCommentErrorMessage: String?
    @State var pageActionErrorMessage: String?
    @State var isConfirmingPageTrash = false
    @State var isShowingLabelEditor = false
    @State var isShowingMoveToSpace = false
    @State var pendingInlineCommentID: String?
    @State var pendingInlineCommentDraft: CommentBody?
    @State var pendingInlineCommentYjsSelection: NativeEditorYjsSelection?
    @State var readerMode = PageReaderMode.edit
    @State var activePanel: PageReaderPanel?
    @State var focusedCommentID: String?
    @State var scrollPosition = ScrollPosition()
    @State var usesFullWidth = false
    @State var realtimePageID: String?
    @FocusState var editorFocusedField: NativeEditorFocus?

    let pageID: String
    let initialTitle: String?
    let initialCommentID: String?
    let focusesEditorOnLoad: Bool
    let pageLoaded: @MainActor (_ pageID: String, _ spaceID: String, _ title: String) -> Void

    init(
        pageID: String,
        initialTitle: String? = nil,
        initialCommentID: String? = nil,
        focusesEditorOnLoad: Bool = false,
        pageLoaded: @escaping @MainActor (_ pageID: String, _ spaceID: String, _ title: String) -> Void = { _, _, _ in }
    ) {
        self.pageID = pageID
        self.initialTitle = initialTitle
        self.initialCommentID = initialCommentID
        self.focusesEditorOnLoad = focusesEditorOnLoad
        self.pageLoaded = pageLoaded
    }

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
                        NativeEditorBodyView(
                            viewModel: editorViewModel,
                            focusedField: $editorFocusedField,
                            isAuthoringEnabled: readerMode == .edit,
                            serverURLString: appState.serverURLString,
                            importAttachment: beginAttachmentImport,
                            applyCommand: applyEditorCommand,
                            applyPendingRemoteUpdate: {
                                resolvePendingRemoteUpdate(.applyRemote)
                            },
                            keepPendingLocalUpdate: {
                                resolvePendingRemoteUpdate(.keepLocal)
                            }
                        )
                        AttachmentLinksView(
                            links: viewModel.attachmentLinks,
                            serverURLString: appState.serverURLString
                        )
                    }
                } else {
                    LoadingStateView(title: "Loading page")
                        .frame(minHeight: 360)
                }
            }
            .padding()
            .frame(maxWidth: usesFullWidth ? .infinity : 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: usesFullWidth)
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        #if os(iOS)
        .safeAreaPadding(.bottom, 72)
        #endif
        .navigationTitle(navigationChromeTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            pageReaderToolbar
        }
        .safeAreaInset(edge: .bottom) {
            if let editorViewModel, readerMode == .edit, editorViewModel.isEditing, editorViewModel.canEdit {
                VStack(spacing: 6) {
                    if isUploadingAttachment {
                        DocmostlyGlassPanel(cornerRadius: 14) {
                            ProgressView("Uploading attachment")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }

                    NativeEditorToolbar(
                        viewModel: editorViewModel,
                        isUploadingAttachment: isUploadingAttachment,
                        importAttachment: beginAttachmentImport,
                        applyCommand: applyEditorCommand,
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
            allowsMultipleSelection: true,
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
        .sheet(isPresented: $isShowingPageHistory) {
            if let editorViewModel {
                PageHistorySheet(
                    pageID: editorViewModel.currentPageID,
                    spaceID: editorViewModel.currentSpaceID,
                    canRestore: editorViewModel.canEdit,
                    viewModel: pageHistoryViewModel,
                    restore: restoreSelectedPageVersion,
                    close: { isShowingPageHistory = false }
                )
            }
        }
        .sheet(isPresented: $isShowingPageExport) {
            if let editorViewModel {
                PageExportSheet(
                    pageID: editorViewModel.currentPageID,
                    viewModel: pageExportViewModel,
                    exportFailed: { errorMessage in
                        pageActionErrorMessage = errorMessage
                    },
                    close: { isShowingPageExport = false }
                )
            }
        }
        .sheet(isPresented: $isShowingPageImport) {
            PageImportSheet(
                spaceID: editorViewModel?.currentSpaceID,
                canImport: editorViewModel?.canEdit == true,
                viewModel: pageImportViewModel,
                importFiles: handlePageImport,
                cancelImport: cancelPageImport,
                close: { isShowingPageImport = false }
            )
        }
        #if os(macOS)
        .inspector(isPresented: activePanelIsPresented) {
            if let activePanel, let editorViewModel {
                PageReaderSupplementaryPanelView(
                    viewModel: viewModel,
                    panel: activePanel,
                    editorViewModel: editorViewModel,
                    pageID: editorViewModel.currentPageID,
                    canEdit: editorViewModel.canEdit,
                    hasPageRestriction: editorViewModel.hasPageRestriction,
                    workspaceSharingDisabled: workspaceSharingDisabled,
                    spaceSharingDisabled: spaceSharingDisabled,
                    publicShareURL: publicShareURL,
                    serverURLString: appState.serverURLString,
                    tableOfContentsItems: tableOfContentsItems,
                    selectHeading: selectHeading,
                    focusedCommentID: focusedCommentID,
                    focusInlineComment: focusInlineComment,
                    markInlineCommentResolved: markInlineCommentResolved,
                    removeInlineComment: removeInlineComment,
                    loadSharingState: loadSharingState,
                    setPublicSharing: setPublicSharing,
                    updateShareOptions: { includeSubPages, searchIndexing in
                        await updateShareOptions(
                            includeSubPages: includeSubPages,
                            searchIndexing: searchIndexing
                        )
                    },
                    close: closeSupplementaryPanel
                )
            }
        }
        #else
        .sheet(item: $activePanel) { panel in
            if let editorViewModel {
                NavigationStack {
                    PageReaderSupplementaryPanelView(
                        viewModel: viewModel,
                        panel: panel,
                        editorViewModel: editorViewModel,
                        pageID: editorViewModel.currentPageID,
                        canEdit: editorViewModel.canEdit,
                        hasPageRestriction: editorViewModel.hasPageRestriction,
                        workspaceSharingDisabled: workspaceSharingDisabled,
                        spaceSharingDisabled: spaceSharingDisabled,
                        publicShareURL: publicShareURL,
                        serverURLString: appState.serverURLString,
                        tableOfContentsItems: tableOfContentsItems,
                        selectHeading: selectHeading,
                        focusedCommentID: focusedCommentID,
                        focusInlineComment: focusInlineComment,
                        markInlineCommentResolved: markInlineCommentResolved,
                        removeInlineComment: removeInlineComment,
                        loadSharingState: loadSharingState,
                        setPublicSharing: setPublicSharing,
                        updateShareOptions: { includeSubPages, searchIndexing in
                            await updateShareOptions(
                                includeSubPages: includeSubPages,
                                searchIndexing: searchIndexing
                            )
                        },
                        close: closeSupplementaryPanel
                    )
                    .navigationTitle(panel.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done", action: closeSupplementaryPanel)
                        }
                    }
                }
                .presentationDetents(panel == .details ? [.large] : [.medium, .large])
            }
        }
        #endif
        .task(id: pageID) {
            await loadNativePage()
            focusRequestedCommentIfAvailable()
        }
        .task(id: PageReaderCollaborationTaskKeys.realtimeEvents(
            pageID: realtimePageID,
            participation: collaborationParticipation
        )) {
            guard realtimePageID != nil else { return }
            await monitorRealtimeEvents()
        }
        .task(id: collaborationPresenceTaskKey) {
            guard let collaborationPresenceTaskKey else { return }
            await monitorCollaborationPresence(participation: collaborationPresenceTaskKey.participation)
        }
        .task(id: PageReaderCollaborationTaskKeys.crdtDocumentSnapshots(
            pageID: realtimePageID,
            participation: collaborationParticipation
        )) {
            guard realtimePageID != nil else { return }
            await monitorCRDTDocumentSnapshots()
        }
        .onChange(of: editorFocusedField) { _, newValue in
            updateEditorFocus(newValue)
        }
        .onChange(of: appState.selectedCommentID) { _, _ in
            focusRequestedCommentIfAvailable()
        }
        .onChange(of: editorViewModel?.localEditRevision) { oldRevision, newRevision in
            guard let oldRevision, let newRevision, oldRevision != newRevision else { return }
            scheduleInlineAutosave()
        }
        .onChange(of: isShowingInlineCommentComposer) { _, isShowing in
            if isShowing == false {
                inlineCommentContext = nil
                pendingInlineCommentID = nil
                pendingInlineCommentDraft = nil
            }
        }
        .onChange(of: readerMode) { _, mode in
            if mode == .read {
                editorFocusedField = nil
                editorViewModel?.clearFocus()
                autosaveInlineEdits()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .active, newPhase != .active {
                autosaveInlineEdits(reloadCompanions: false)
            }
        }
        .onChange(of: editorViewModel?.canEdit) { _, canEdit in
            if canEdit == false {
                autosaveInlineEdits(reloadCompanions: false)
                readerMode = .read
            }
        }
        .onDisappear {
            autosaveInlineEdits()
        }
    }

}

extension PageReaderView {
    var collaborationParticipation: NativeEditorCollaborationParticipation {
        guard let editorViewModel else { return .receiveOnly }
        guard readerMode == .edit, editorViewModel.canEdit else { return .receiveOnly }
        return .interactive
    }

    var collaborationPresenceTaskKey: PageReaderCollaborationPresenceTaskKey? {
        PageReaderCollaborationTaskKeys.collaborationPresence(
            pageID: realtimePageID,
            participation: collaborationParticipation,
            isVisible: scenePhase == .active
        )
    }
}
