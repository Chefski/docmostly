import SwiftUI
import UniformTypeIdentifiers

struct PageReaderView: View {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    @State var viewModel = PageReaderViewModel()
    @State var editorViewModel: NativeRichEditorViewModel?
    @State var realtimeEventClient = NativeEditorRealtimeEventClient()
    @State var collaborationPresenceClient = NativeEditorCollaborationPresenceClient()
    @State var attachmentImportKind: NativeEditorAttachmentImportKind?
    @State var isShowingAttachmentImporter = false
    @State var isShowingMentionPicker = false
    @State var isShowingInlineCommentComposer = false
    @State var isUploadingAttachment = false
    @State var attachmentUploadErrorMessage: String?
    @State var inlineCommentContext: NativeEditorInlineCommentContext?
    @State var inlineCommentErrorMessage: String?
    @State var pageActionErrorMessage: String?
    @State var isConfirmingPageTrash = false
    @State var isShowingLabelEditor = false
    @State var isShowingMoveToSpace = false
    @State var pendingInlineCommentID: String?
    @State var pendingInlineCommentDraft: String?
    @State var pendingInlineCommentYjsSelection: NativeEditorYjsSelection?
    @State var readerMode = PageReaderMode.edit
    @State var activePanel: PageReaderPanel?
    @State var scrollPosition = ScrollPosition()
    @State var usesFullWidth = false
    @State var realtimePageID: String?
    @FocusState var editorFocusedField: NativeEditorFocus?

    let pageID: String
    let initialTitle: String? = nil

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
                            isAuthoringEnabled: readerMode == .edit
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
            .scrollTargetLayout()
        }
        .scrollPosition($scrollPosition)
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(pageNavigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let editorViewModel, editorViewModel.errorMessage == nil {
                    Picker("Page Mode", selection: $readerMode) {
                        ForEach(PageReaderMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .disabled(editorViewModel.canEdit == false)

                    if let pageShareURL {
                        ShareLink(item: pageShareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("Share", systemImage: "square.and.arrow.up") { }
                            .disabled(true)
                    }

                    Button("Comments", systemImage: "text.bubble", action: showComments)

                    Button("Table of Contents", systemImage: "list.bullet", action: showTableOfContents)

                    Menu("More", systemImage: "ellipsis") {
                        Button("Copy Link", systemImage: "link", action: copyPageLink)

                        Button("Copy as Markdown", systemImage: "doc.plaintext", action: copyPageMarkdown)

                        #if os(macOS)
                        Button("Open in New Window", systemImage: "macwindow", action: openCurrentPageInNewWindow)
                        #endif

                        Button(
                            viewModel.isFavoritePage ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: viewModel.isFavoritePage ? "star.fill" : "star",
                            action: toggleFavorite
                        )
                        .disabled(viewModel.isTogglingFavorite)

                        Button(
                            viewModel.isWatchingPage == true ? "Stop Watching" : "Watch Page",
                            systemImage: viewModel.isWatchingPage == true ? "eye.slash" : "eye",
                            action: toggleWatch
                        )
                        .disabled(viewModel.isTogglingWatch)

                        Divider()

                        Toggle(isOn: $usesFullWidth) {
                            Label("Full Width", systemImage: "arrow.left.and.right")
                        }

                        Divider()

                        if editorViewModel.canEdit {
                            Button("Edit Labels", systemImage: "tag", action: showLabelEditor)
                        }
                        if editorViewModel.currentSpaceID != nil {
                            Button("Move", systemImage: "arrow.right", action: showMoveToSpace)
                        }
                        Button("Duplicate", systemImage: "doc.on.doc", action: duplicateCurrentPage)

                        Divider()

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
            if let editorViewModel, readerMode == .edit, editorViewModel.isEditing, editorViewModel.canEdit {
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
        #if os(macOS)
        .inspector(isPresented: activePanelIsPresented) {
            if let activePanel, let editorViewModel {
                PageReaderSupplementaryPanelView(
                    viewModel: viewModel,
                    panel: activePanel,
                    pageID: editorViewModel.currentPageID,
                    tableOfContentsItems: tableOfContentsItems,
                    selectHeading: selectHeading,
                    markInlineCommentResolved: markInlineCommentResolved,
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
                        pageID: editorViewModel.currentPageID,
                        tableOfContentsItems: tableOfContentsItems,
                        selectHeading: selectHeading,
                        markInlineCommentResolved: markInlineCommentResolved,
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
                .presentationDetents([.medium, .large])
            }
        }
        #endif
        .task(id: pageID) {
            await loadNativePage()
        }
        .task(id: realtimePageID) {
            guard realtimePageID != nil else { return }
            await monitorRemotePageChanges()
        }
        .task(id: realtimePageID) {
            guard realtimePageID != nil else { return }
            await monitorRealtimeEvents()
        }
        .task(id: realtimePageID) {
            guard realtimePageID != nil else { return }
            await monitorCollaborationPresence()
        }
        .task(id: realtimePageID) {
            guard realtimePageID != nil else { return }
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
        .onChange(of: readerMode) { _, mode in
            if mode == .read {
                editorFocusedField = nil
                editorViewModel?.clearFocus()
                autosaveInlineEdits()
            }
        }
        .onChange(of: editorViewModel?.canEdit) { _, canEdit in
            if canEdit == false {
                readerMode = .read
            }
        }
        .onDisappear {
            autosaveInlineEdits()
        }
    }

}
