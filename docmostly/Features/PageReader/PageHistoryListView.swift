import SwiftUI

struct PageHistoryListView: View {
    let pageID: String
    @Bindable var viewModel: PageHistoryViewModel
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: selectedVersionBinding) {
            if viewModel.versions.isEmpty && viewModel.isLoadingList {
                ProgressView("Loading versions")
            } else if viewModel.versions.isEmpty {
                ContentUnavailableView(
                    "No page history saved yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Docmost has not created saved versions for this page.")
                )
            } else {
                ForEach(viewModel.versions) { version in
                    PageHistoryVersionRow(version: version)
                        .tag(version.id)
                        .task {
                            guard version.id == viewModel.versions.last?.id else { return }
                            await viewModel.loadNextPage(pageID: pageID, appState: appState)
                        }
                }

                if viewModel.isLoadingList {
                    ProgressView()
                }
            }
        }
    }

    private var selectedVersionBinding: Binding<String?> {
        Binding {
            viewModel.selectedVersion?.id
        } set: { versionID in
            guard let versionID else { return }
            Task {
                await viewModel.selectVersion(versionID, appState: appState)
            }
        }
    }
}
