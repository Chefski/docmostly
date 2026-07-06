import SwiftUI

struct PageBrowserRowView: View {
    let item: PageBrowserItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PageBrowserItemIcon(icon: item.icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(item.subtitle)

                    if let updatedAt = item.updatedAt {
                        Text(updatedAt.formatted(.relative(presentation: .named)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: PageBrowserMetrics.rowHeight, alignment: .leading)
        .contentShape(.rect)
    }
}
