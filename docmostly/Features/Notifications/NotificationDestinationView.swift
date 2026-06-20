import SwiftUI

struct NotificationDestinationView: View {
    @Environment(AppState.self) private var appState

    let notification: DocmostNotification

    var body: some View {
        if let page = notification.page {
            PageReaderView(pageID: page.slugId)
                .task(id: notification.id) {
                    appState.selectPage(
                        id: page.slugId,
                        spaceID: notification.spaceId ?? notification.space?.id
                    )
                }
        } else {
            ContentUnavailableView("Page unavailable", systemImage: "bell")
        }
    }
}
