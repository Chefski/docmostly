import SwiftUI

struct PageReaderDestinationView: View {
    @Environment(AppState.self) private var appState

    let pageID: String

    var body: some View {
        PageReaderView(pageID: pageID)
            .task(id: pageID) {
                appState.selectedPageID = pageID
            }
    }
}
