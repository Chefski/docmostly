import SwiftUI

struct PageTreeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()

    let space: DocmostSpace

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.nodes.isEmpty {
                ProgressView("Loading pages")
            }

            ForEach(viewModel.nodes) { node in
                PageTreeNodeView(node: node, depth: 0, viewModel: viewModel)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }

            if viewModel.nodes.isEmpty && viewModel.isLoading == false {
                Text(appState.isOffline ? "No cached pages" : "No pages")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(space.name)
        .refreshable {
            await viewModel.loadRoot(spaceId: space.id, appState: appState)
        }
        .task(id: space.id) {
            await viewModel.loadRoot(spaceId: space.id, appState: appState)
        }
        .navigationDestination(for: PageTreeNode.self) { node in
            PageReaderDestinationView(pageID: node.slugId)
        }
    }
}
