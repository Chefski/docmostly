import SwiftUI

struct PageReaderDestinationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.pageOpenPresentation) private var pageOpenPresentation

    let pageID: String

    var body: some View {
        PageReaderView(pageID: pageID)
            .task(id: pageID) {
                appState.selectPage(id: pageID)
            }
            .onDisappear {
                guard pageOpenPresentation.shouldClearSelectedPageOnReaderDisappear else { return }
                appState.clearSelectedPage(ifMatching: pageID)
            }
    }
}
