import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = FavoritesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.favorites.isEmpty {
                ProgressView("Loading favorites")
                    .frame(maxWidth: .infinity)
            } else if let errorMessage = viewModel.errorMessage, viewModel.favorites.isEmpty {
                ContentUnavailableView {
                    Label("Couldn’t Load Favorites", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try Again", systemImage: "arrow.clockwise", action: retry)
                }
            } else if viewModel.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites Yet",
                    systemImage: "star",
                    description: Text("Pages and spaces you star will appear here.")
                )
            } else {
                ForEach(viewModel.sections) { section in
                    Section(section.type.sectionTitle) {
                        ForEach(section.favorites) { favorite in
                            FavoriteListRow(
                                favorite: favorite,
                                isMutating: viewModel.mutatingFavoriteIDs.contains(favorite.id),
                                remove: { remove(favorite) }
                            )
                        }
                    }
                }
            }

            if viewModel.hasNextPage {
                FavoritesPaginationView(
                    isLoading: viewModel.isLoadingNextPage,
                    errorMessage: viewModel.nextPageErrorMessage,
                    loadNextPage: loadNextPage
                )
            }

            if let errorMessage = viewModel.errorMessage, viewModel.favorites.isEmpty == false {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Favorites")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh Favorites", systemImage: "arrow.clockwise", action: retry)
                    .labelStyle(.iconOnly)
                    .help("Refresh Favorites")
            }
        }
        .task(id: appState.favoriteRevision) {
            await viewModel.load(appState: appState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            retry()
        }
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .navigationDestination(for: DocmostFavorite.self) { favorite in
            FavoriteDestinationView(favorite: favorite)
        }
        .pageOpenDestination()
    }

    private func retry() {
        Task {
            await viewModel.load(appState: appState)
        }
    }

    private func loadNextPage() {
        Task {
            await viewModel.loadNextPage(appState: appState)
        }
    }

    private func remove(_ favorite: DocmostFavorite) {
        Task {
            await viewModel.remove(favorite, appState: appState)
        }
    }
}
