import SwiftUI

struct PageTreeSpaceActionsMenu: View {
    @Environment(AppState.self) private var appState

    let space: DocmostSpace
    let viewModel: PageTreeViewModel
    let showTrash: () -> Void
    let showSpaceSettings: () -> Void

    var body: some View {
        Menu("Space Actions", systemImage: "ellipsis") {
            Button(favoriteTitle, systemImage: favoriteSystemImage, action: toggleFavorite)
                .disabled(viewModel.isTogglingSpaceFavorite || viewModel.isLoadingSpaceActions)

            Button(watchTitle, systemImage: watchSystemImage, action: toggleWatch)
                .disabled(viewModel.isTogglingSpaceWatch || viewModel.isLoadingSpaceActions)

            Divider()

            Button("Space Settings", systemImage: "gearshape", action: showSpaceSettings)

            Button("Trash", systemImage: "trash", role: .destructive, action: showTrash)
        }
        .labelStyle(.iconOnly)
    }

    private var favoriteTitle: String {
        viewModel.isFavoriteSpace ? "Remove from Favorites" : "Add to Favorites"
    }

    private var favoriteSystemImage: String {
        viewModel.isFavoriteSpace ? "star.slash" : "star"
    }

    private var watchTitle: String {
        viewModel.isWatchingSpace == true ? "Unwatch Space" : "Watch Space"
    }

    private var watchSystemImage: String {
        viewModel.isWatchingSpace == true ? "eye.slash" : "eye"
    }

    private func toggleFavorite() {
        Task {
            await viewModel.toggleSpaceFavorite(spaceId: space.id, appState: appState)
        }
    }

    private func toggleWatch() {
        Task {
            await viewModel.toggleSpaceWatch(spaceId: space.id, appState: appState)
        }
    }
}
