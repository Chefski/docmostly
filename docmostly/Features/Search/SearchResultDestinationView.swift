import SwiftUI

struct SearchResultDestinationView: View {
    @Environment(AppState.self) private var appState

    let result: DocmostSearchResult

    var body: some View {
        PageReaderView(pageID: result.slugId)
            .task(id: result.id) {
                appState.selectedSpaceID = result.space.id
                appState.selectedPageID = result.slugId
            }
    }
}
