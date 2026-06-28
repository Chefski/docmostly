import SwiftUI

struct MacPageWindowView: View {
    let route: MacPageWindowRoute

    var body: some View {
        NavigationStack {
            PageReaderView(pageID: route.pageID, initialTitle: route.displayTitle)
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}
