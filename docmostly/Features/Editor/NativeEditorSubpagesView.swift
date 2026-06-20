import SwiftUI

struct NativeEditorSubpagesView: View {
    @Environment(AppState.self) private var appState
    @State private var pages: [DocmostPage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    let pageID: String
    let spaceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView("Loading subpages")
            }

            ForEach(pages) { page in
                NavigationLink(value: page) {
                    PageListRowView(page: page, systemImage: page.hasChildren == true ? "doc.on.doc" : "doc.text")
                }
            }

            if pages.isEmpty && isLoading == false && errorMessage == nil {
                Text("No subpages")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .task(id: taskID) {
            await load()
        }
        .navigationDestination(for: DocmostPage.self) { page in
            PageReaderView(pageID: page.slugId)
                .task(id: page.id) {
                    appState.selectedSpaceID = page.spaceId
                    appState.selectedPageID = page.slugId
                }
        }
    }

    private var taskID: String {
        "\(pageID)-\(spaceID ?? "unknown")"
    }

    private func load() async {
        guard let spaceID else {
            errorMessage = "Subpages need the current space."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            pages = try await appState.loadSidebarPages(spaceId: spaceID, pageId: pageID)
        } catch {
            pages = []
            errorMessage = error.localizedDescription
        }
    }
}
