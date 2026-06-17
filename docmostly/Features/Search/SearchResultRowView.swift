import SwiftUI

struct SearchResultRowView: View {
    let result: DocmostSearchResult

    var body: some View {
        NavigationLink(value: result) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(result.title.isEmpty ? "Untitled" : result.title)
                        .foregroundStyle(.primary)
                } icon: {
                    Text(result.icon?.isEmpty == false ? result.icon ?? "📄" : "📄")
                }

                Text(result.space.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let highlight = result.highlight, highlight.isEmpty == false {
                    Text(highlight.removingHTMLTags())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
