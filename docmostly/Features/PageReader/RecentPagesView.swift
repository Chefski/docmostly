import SwiftUI

struct RecentPagesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section("Recent cached pages") {
                ForEach(appState.recentCachedPages()) { page in
                    Button(action: { select(page) }, label: {
                        Label(page.title, systemImage: "clock")
                    })
                }
            }
        }
        .navigationTitle("Recent")
    }

    private func select(_ page: CachedPage) {
        appState.selectedPageID = page.slugId
    }
}
