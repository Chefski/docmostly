import SwiftUI

struct PageReaderMetadataView: View {
    let breadcrumbs: [DocmostPage]
    let labels: [DocmostLabel]
    let selectPage: (DocmostPage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if breadcrumbs.isEmpty == false {
                PageBreadcrumbTrailView(breadcrumbs: breadcrumbs, selectPage: selectPage)
            }

            if labels.isEmpty == false {
                PageLabelChipsView(labels: labels)
            }
        }
    }
}

private struct PageBreadcrumbTrailView: View {
    let breadcrumbs: [DocmostPage]
    let selectPage: (DocmostPage) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(breadcrumbs.enumerated(), id: \.element.id) { index, page in
                    Button(page.title.isEmpty ? "Untitled" : page.title) {
                        selectPage(page)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if index < breadcrumbs.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct PageLabelChipsView: View {
    let labels: [DocmostLabel]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(labels) { label in
                    Text(label.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
