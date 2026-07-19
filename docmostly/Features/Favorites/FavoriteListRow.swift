import SwiftUI

struct FavoriteListRow: View {
    @Environment(AppState.self) private var appState

    let favorite: DocmostFavorite
    let isMutating: Bool
    let remove: () -> Void

    var body: some View {
        Group {
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
        .opacity(isMutating ? 0.6 : 1)
        .disabled(isMutating)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Remove Favorite", systemImage: "star.slash", role: .destructive, action: remove)
        }
        .contextMenu {
            Button("Remove from Favorites", systemImage: "star.slash", role: .destructive, action: remove)
        }
    }
}
