import SwiftUI

struct PageReaderView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageReaderViewModel()
    @State private var editorViewModel: NativeRichEditorViewModel?
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
                NativeEditorToolbar(viewModel: editorViewModel) {
                    editorFocusedField = nil
                    editorViewModel.clearFocus()
                    autosaveInlineEdits()
                }
            }
        }
        .task(id: pageID) {
            await loadNativePage()
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
}
