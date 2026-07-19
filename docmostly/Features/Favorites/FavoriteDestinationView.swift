import SwiftUI

struct FavoriteDestinationView: View {
    let favorite: DocmostFavorite

    var body: some View {
        switch favorite.type {
        case .page:
            if let target = PageOpenTarget(favorite: favorite) {
                PageOpenDestinationView(target: target)
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
