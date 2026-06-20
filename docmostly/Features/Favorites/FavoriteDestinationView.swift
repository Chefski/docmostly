import SwiftUI

struct FavoriteDestinationView: View {
    @Environment(AppState.self) private var appState

    let favorite: DocmostFavorite

    var body: some View {
        switch favorite.type {
        case .page:
            if let targetID = favorite.targetID {
                PageReaderView(pageID: targetID)
                    .task(id: favorite.id) {
                        appState.selectedSpaceID = favorite.page?.spaceId ?? favorite.spaceId ?? appState.selectedSpaceID
                        appState.selectedPageID = targetID
                    }
            } else {
                ContentUnavailableView("Page unavailable", systemImage: "doc.text")
            }
        case .space:
            if let targetID = favorite.targetID {
                SpaceDestinationView(spaceID: targetID)
            } else {
                ContentUnavailableView("Space unavailable", systemImage: "square.stack.3d.up")
            }
        case .template:
            ContentUnavailableView("Template unavailable", systemImage: "doc.on.doc")
        }
    }
}
