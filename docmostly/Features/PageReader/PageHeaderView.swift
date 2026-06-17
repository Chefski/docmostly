import SwiftUI

struct PageHeaderView: View {
    let page: DocmostPage
    let isFromCache: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(page.icon?.isEmpty == false ? page.icon ?? "📄" : "📄")
                    .font(.title2)
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.largeTitle)
                    .bold()
            }

            HStack {
                if let updatedAt = page.updatedAt {
                    Label(updatedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                }

                if isFromCache {
                    OfflineBadgeView(text: "Cached")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
