import SwiftUI

struct PageHistoryVersionRow: View {
    let version: DocmostPageHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(version.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Saved version")
                    .font(.headline)
                Spacer()
                Text(version.versionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(version.lastUpdatedBy?.name ?? "Unknown editor")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
