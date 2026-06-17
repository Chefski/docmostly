import SwiftUI
import UniformTypeIdentifiers

struct PageReaderView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageReaderViewModel()
    @State private var editorViewModel: NativeRichEditorViewModel?
    @State private var attachmentImportKind: NativeEditorAttachmentImportKind?
    @State private var isShowingAttachmentImporter = false
    @State private var isUploadingAttachment = false
    @State private var attachmentUploadErrorMessage: String?
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
                        NativeEditorBodyView(viewModel: editorViewModel, focusedField: $editorFocusedField)
                        AttachmentLinksView(
                            links: viewModel.attachmentLinks,
                            serverURLString: appState.serverURLString
                        )
                        CommentsSectionView(viewModel: viewModel, pageID: editorViewModel.currentPageID)
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

                if let editorViewModel, editorViewModel.isSaving {
                    ProgressView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let editorViewModel, editorViewModel.isEditing {
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
                        importAttachment: beginAttachmentImport
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
        .task(id: pageID) {
            await loadNativePage()
        }
        .task(id: editorViewModel?.currentPageID) {
            await monitorRemotePageChanges()
        }
        .onChange(of: editorFocusedField) { _, newValue in
            updateEditorFocus(newValue)
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
        let editorViewModel = NativeRichEditorViewModel(pageID: pageID)
        self.editorViewModel = editorViewModel

        await editorViewModel.load(appState: appState)
        if editorViewModel.errorMessage == nil {
            await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
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

    private func monitorRemotePageChanges() async {
        guard let editorViewModel else { return }
        editorViewModel.realtimeStatus = .connecting

        do {
            _ = try appState.collaborationWebSocketURL()
            _ = try await appState.loadCollaborationToken()
        } catch {
            editorViewModel.realtimeStatus = .unsupported(error.localizedDescription)
        }

        while Task.isCancelled == false {
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
}
