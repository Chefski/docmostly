import SwiftUI

struct FavoriteRowView: View {
    let favorite: DocmostFavorite

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: favorite.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(favorite.title)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(favorite.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension DocmostFavorite {
    var targetID: String? {
        switch type {
        case .page:
            page?.slugId ?? pageId
        case .space:
            space?.id ?? spaceId
        case .template:
            template?.id ?? templateId
        }
    }

    var title: String {
        switch type {
        case .page:
            page?.title.isEmpty == false ? page?.title ?? "Untitled" : "Untitled"
        case .space:
            space?.name ?? "Space"
        case .template:
            template?.title ?? "Template"
        }
    }

    var subtitle: String {
        switch type {
        case .page:
            space?.name ?? "Page"
        case .space:
            space?.slug ?? "Space"
        case .template:
            template?.description ?? "Template favorite"
        }
    }

    var systemImage: String {
        switch type {
        case .page:
            "doc.text"
        case .space:
            "square.stack.3d.up"
        case .template:
            "doc.on.doc"
        }
    }
}
