import SwiftUI

struct SpaceRowView: View {
    let space: DocmostSpace

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(space.name)
                    .foregroundStyle(.primary)
                if let description = space.description, description.isEmpty == false {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            SpaceIconView(space: space)
        }
    }
}
