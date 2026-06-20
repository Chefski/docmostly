import SwiftUI

struct MainShellDetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let selectedPageID = appState.selectedPageID {
                PageReaderView(pageID: selectedPageID)
            } else {
                RecentPagesView()
            }
        }
        .navigationSplitViewColumnWidth(min: 420, ideal: 720)
    }
}
