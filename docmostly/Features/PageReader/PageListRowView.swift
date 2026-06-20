import SwiftUI

struct PageListRowView: View {
    let page: DocmostPage
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(page.icon?.isEmpty == false ? page.icon ?? "📄" : "📄")
                    Text(page.title.isEmpty ? "Untitled" : page.title)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                if let updatedAt = page.updatedAt {
                    Text(updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let spaceName = page.space?.name, spaceName.isEmpty == false {
                    Text(spaceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
