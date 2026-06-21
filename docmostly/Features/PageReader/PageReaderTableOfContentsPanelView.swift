import SwiftUI

struct PageReaderTableOfContentsPanelView: View {
    let items: [PageReaderTableOfContentsItem]
    let select: (PageReaderTableOfContentsItem) -> Void

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView(
                "No table of contents",
                systemImage: "list.bullet",
                description: Text("Add headings to this page to generate a table of contents.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        Button {
                            select(item)
                        } label: {
                            Text(item.title)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.leading, CGFloat(max(item.level - 1, 0)) * 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Go to \(item.title)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }
}
