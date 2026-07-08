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
                    favoriteRow(favorite)
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
            ToolbarItem(placement: .primaryAction) {
                Menu("Favorites Actions", systemImage: "ellipsis.circle") {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.load(appState: appState)
                        }
                    }
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
        .pageOpenDestination()
    }

    @ViewBuilder
    private func favoriteRow(_ favorite: DocmostFavorite) -> some View {
        switch favorite.type {
        case .page:
            if let target = PageOpenTarget(favorite: favorite) {
                PageOpenLink(target: target) {
                    FavoriteRowView(favorite: favorite)
                }
            } else {
                FavoriteRowView(favorite: favorite)
            }
        case .space:
            if let targetID = favorite.targetID {
                #if os(macOS)
                Button {
                    appState.selectSpace(id: targetID)
                } label: {
                    FavoriteRowView(favorite: favorite)
                }
                .buttonStyle(.plain)
                #else
                NavigationLink(value: favorite) {
                    FavoriteRowView(favorite: favorite)
                }
                #endif
            } else {
                FavoriteRowView(favorite: favorite)
            }
        case .template:
            FavoriteRowView(favorite: favorite)
        }
    }
}
