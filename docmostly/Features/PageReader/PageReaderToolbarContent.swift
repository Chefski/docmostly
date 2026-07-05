import SwiftUI

extension PageReaderView {
    @ToolbarContentBuilder
    var pageReaderToolbar: some ToolbarContent {
        if let editorViewModel, editorViewModel.errorMessage == nil {
            #if os(iOS)
            ToolbarItem(placement: .principal) {
                pageModePicker(editorViewModel: editorViewModel)
            }

            ToolbarItem(placement: .primaryAction) {
                pageActionsMenu(editorViewModel: editorViewModel)
            }
            #else
            ToolbarItemGroup(placement: .primaryAction) {
                pageModePicker(editorViewModel: editorViewModel)
                pageActionsMenu(editorViewModel: editorViewModel)
            }
            #endif
        }

        if let editorViewModel, editorViewModel.isSaving {
            ToolbarItem(placement: .primaryAction) {
                ProgressView()
            }
        }
    }

    private func pageModePicker(editorViewModel: NativeRichEditorViewModel) -> some View {
        Picker("Page Mode", selection: $readerMode) {
            ForEach(PageReaderMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .disabled(editorViewModel.canEdit == false)
    }

    private func pageActionsMenu(editorViewModel: NativeRichEditorViewModel) -> some View {
        #if os(macOS)
        PageReaderPageActionsMenu(
            pageShareURL: pageShareURL,
            activePanel: activePanel,
            usesFullWidth: $usesFullWidth,
            isFavoritePage: viewModel.isFavoritePage,
            isTogglingFavorite: viewModel.isTogglingFavorite,
            isWatchingPage: viewModel.isWatchingPage,
            isTogglingWatch: viewModel.isTogglingWatch,
            canEdit: editorViewModel.canEdit,
            canMoveToSpace: editorViewModel.currentSpaceID != nil,
            showComments: showComments,
            showTableOfContents: showTableOfContents,
            copyPageLink: copyPageLink,
            copyPageMarkdown: copyPageMarkdown,
            toggleFavorite: toggleFavorite,
            toggleWatch: toggleWatch,
            showLabelEditor: showLabelEditor,
            showMoveToSpace: showMoveToSpace,
            duplicateCurrentPage: duplicateCurrentPage,
            confirmTrash: { isConfirmingPageTrash = true },
            openCurrentPageInNewWindow: openCurrentPageInNewWindow
        )
        #else
        PageReaderPageActionsMenu(
            pageShareURL: pageShareURL,
            activePanel: activePanel,
            usesFullWidth: $usesFullWidth,
            isFavoritePage: viewModel.isFavoritePage,
            isTogglingFavorite: viewModel.isTogglingFavorite,
            isWatchingPage: viewModel.isWatchingPage,
            isTogglingWatch: viewModel.isTogglingWatch,
            canEdit: editorViewModel.canEdit,
            canMoveToSpace: editorViewModel.currentSpaceID != nil,
            showComments: showComments,
            showTableOfContents: showTableOfContents,
            copyPageLink: copyPageLink,
            copyPageMarkdown: copyPageMarkdown,
            toggleFavorite: toggleFavorite,
            toggleWatch: toggleWatch,
            showLabelEditor: showLabelEditor,
            showMoveToSpace: showMoveToSpace,
            duplicateCurrentPage: duplicateCurrentPage,
            confirmTrash: { isConfirmingPageTrash = true }
        )
        #endif
    }
}
