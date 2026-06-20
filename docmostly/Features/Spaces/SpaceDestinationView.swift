import SwiftUI

struct SpaceDestinationView: View {
    @Environment(AppState.self) private var appState

    let spaceID: String

    var body: some View {
        Group {
            if let space {
                PageTreeView(space: space)
                    .task {
                        appState.selectSpace(id: space.id)
                    }
            } else {
                ContentUnavailableView("Space unavailable", systemImage: "square.stack.3d.up")
            }
        }
    }

    private var space: DocmostSpace? {
        appState.spaces.first { $0.id == spaceID }
    }
}
