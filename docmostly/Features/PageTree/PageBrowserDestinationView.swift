import SwiftUI

struct PageBrowserDestinationView: View {
    @Environment(AppState.self) private var appState

    let item: PageBrowserItem

    var body: some View {
        PageReaderView(pageID: item.slugId)
            .task(id: item.id) {
                appState.selectPage(id: item.slugId, spaceID: item.spaceId)
            }
    }
}
