import SwiftUI

struct PageTrashSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let space: DocmostSpace
    let viewModel: PageTreeViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoadingTrash {
                    ProgressView("Loading trash")
                }

                ForEach(viewModel.trashPages) { page in
                    PageTrashRow(page: page, viewModel: viewModel)
                }

                if viewModel.trashPages.isEmpty, viewModel.isLoadingTrash == false {
                    ContentUnavailableView("Trash is Empty", systemImage: "trash")
                }
            }
            .navigationTitle("Trash")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
            .task(id: space.id) {
                await viewModel.loadTrash(spaceId: space.id, appState: appState)
            }
        }
    }
}
