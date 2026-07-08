import SwiftUI

struct PageHistoryDetailView: View {
    let pageID: String
    let spaceID: String?
    let canRestore: Bool
    @Bindable var viewModel: PageHistoryViewModel
    let requestRestore: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        if viewModel.isLoadingSelection {
            LoadingStateView(title: "Loading version")
        } else if let errorMessage = viewModel.errorMessage {
            ErrorStateView(title: "History unavailable", message: errorMessage) {
                Task {
                    await viewModel.loadInitial(pageID: pageID, appState: appState)
                }
            }
        } else if let selectedVersion = viewModel.selectedVersion {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHistoryVersionHeader(
                        version: selectedVersion,
                        canRestore: canRestore && viewModel.canRequestRestoreConfirmation,
                        isRestoring: viewModel.isRestoring,
                        restore: requestRestore
                    )

                    if let restoreErrorMessage = viewModel.restoreErrorMessage {
                        ErrorStateView(title: "Restore failed", message: restoreErrorMessage, retry: nil)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.selectedDocument.blocks, id: \.id) { block in
                            NativeEditorRichBlockPreviewView(
                                block: block,
                                pageID: pageID,
                                spaceID: spaceID,
                                serverURLString: appState.serverURLString
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: 900, alignment: .leading)
            }
        } else {
            ContentUnavailableView(
                "Select a version",
                systemImage: "clock",
                description: Text("Choose a saved version to preview its content.")
            )
        }
    }
}
