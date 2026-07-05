import SwiftUI

struct PageHistorySheet: View {
    let pageID: String
    let spaceID: String?
    let canRestore: Bool
    @Bindable var viewModel: PageHistoryViewModel
    let restore: () async -> Bool
    let close: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            PageHistoryListView(pageID: pageID, viewModel: viewModel)
                .navigationTitle("Page History")
        } detail: {
            PageHistoryDetailView(
                pageID: pageID,
                spaceID: spaceID,
                canRestore: canRestore,
                viewModel: viewModel
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
            }
        } message: {
            Text("Any unsaved edits that are not in page history may be lost.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", action: close)
            }
        }
    }

    private var restoreConfirmationBinding: Binding<Bool> {
        Binding {
            viewModel.pendingRestoreVersion != nil
        } set: { isPresented in
            if isPresented == false {
                viewModel.cancelRestoreConfirmation()
            }
        }
    }
}
