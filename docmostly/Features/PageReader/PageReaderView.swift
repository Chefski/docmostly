import SwiftUI

struct PageReaderView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageReaderViewModel()
    @State private var editorDestination: EditorDestination?

    let pageID: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let page = viewModel.page {
                    PageHeaderView(page: page, isFromCache: viewModel.isFromCache)
                    HTMLPageWebView(html: viewModel.html, baseURLString: appState.serverURLString)
                        .frame(minHeight: 480)
                        .clipShape(.rect(cornerRadius: 8))
                    AttachmentLinksView(links: viewModel.attachmentLinks, serverURLString: appState.serverURLString)
                    CommentsSectionView(viewModel: viewModel)
                } else if viewModel.isLoading {
                    LoadingStateView(title: "Loading page")
                        .frame(minHeight: 360)
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorStateView(title: "Page unavailable", message: errorMessage, retry: retry)
                }
            }
            .padding()
            .frame(maxWidth: 900, alignment: .leading)
        }
        .safeAreaPadding(.bottom, 72)
        .navigationTitle(viewModel.page?.title ?? "Page")
        .toolbar {
            if let page = viewModel.page {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Refresh", systemImage: "arrow.clockwise", action: retry)
                    Button("Edit", systemImage: "square.and.pencil") {
                        if let url = appState.webURL(for: page) {
                            editorDestination = EditorDestination(url: url)
                        }
                    }
                    .disabled(appState.isOffline)
                }
            }
        }
        .sheet(item: $editorDestination) { destination in
            DocmostEditorView(url: destination.url)
        }
        .task(id: pageID) {
            await viewModel.load(pageID: pageID, appState: appState)
        }
    }

    private func retry() {
        Task {
            await viewModel.load(pageID: pageID, appState: appState)
        }
    }
}
