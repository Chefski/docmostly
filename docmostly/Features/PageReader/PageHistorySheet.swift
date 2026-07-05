import SwiftUI

struct PageHistorySheet: View {
    let pageID: String
    let spaceID: String?
    let canRestore: Bool
    @Bindable var viewModel: PageHistoryViewModel
    let restore: () async -> Bool
    let close: () -> Void
    @Environment(AppState.self) private var appState
    @State private var isShowingRestoreConfirmation = false

    var body: some View {
        NavigationSplitView {
            PageHistoryListView(pageID: pageID, viewModel: viewModel)
                .navigationTitle("Page History")
        } detail: {
            PageHistoryDetailView(
                pageID: pageID,
                spaceID: spaceID,
                canRestore: canRestore,
                viewModel: viewModel,
                requestRestore: requestRestoreConfirmation
            )
                .navigationTitle(viewModel.selectedVersion?.title ?? "Version")
        }
        .task(id: pageID) {
            await viewModel.loadInitial(pageID: pageID, appState: appState)
        }
        .confirmationDialog(
            "Restore this version?",
            isPresented: restoreConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Restore Version", role: .destructive) {
                Task {
                    if await restore() {
                        close()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelRestoreConfirmation()
                isShowingRestoreConfirmation = false
            }
        } message: {
            Text("Any unsaved edits that are not in page history may be lost.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    viewModel.cancelRestoreConfirmation()
                    close()
                }
            }
        }
    }

    private var restoreConfirmationBinding: Binding<Bool> {
        Binding {
            isShowingRestoreConfirmation
        } set: { isPresented in
            isShowingRestoreConfirmation = isPresented
        }
    }

    private func requestRestoreConfirmation() {
        viewModel.requestRestoreConfirmation()
        isShowingRestoreConfirmation = viewModel.pendingRestoreVersion != nil
    }
}
