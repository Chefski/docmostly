import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FavoritesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading favorites")
            }

            Section("Favorites") {
                ForEach(viewModel.favorites) { favorite in
                    if favorite.targetID == nil {
                        FavoriteRowView(favorite: favorite)
                    } else {
                        NavigationLink(value: favorite) {
                            FavoriteRowView(favorite: favorite)
                        }
                    }
                }
            }

            if viewModel.favorites.isEmpty && viewModel.isLoading == false {
                ContentUnavailableView("No Favorites", systemImage: "star")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await viewModel.load(appState: appState)
                }
            }
        }
        .task {
            await viewModel.load(appState: appState)
        }
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .navigationDestination(for: DocmostFavorite.self) { favorite in
            FavoriteDestinationView(favorite: favorite)
        }
    }
}
