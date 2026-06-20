import SwiftUI

struct NotificationDestinationView: View {
    @Environment(AppState.self) private var appState

    let notification: DocmostNotification

    var body: some View {
        if let page = notification.page {
            PageReaderView(pageID: page.slugId)
                .task(id: notification.id) {
                    appState.selectedSpaceID = notification.spaceId ?? notification.space?.id ?? appState.selectedSpaceID
                    appState.selectedPageID = page.slugId
                }
        } else {
            ContentUnavailableView("Page unavailable", systemImage: "bell")
        }
    }
}
