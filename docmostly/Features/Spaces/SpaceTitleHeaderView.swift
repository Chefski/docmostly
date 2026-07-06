import SwiftUI

struct SpaceTitleHeaderView: View {
    let space: DocmostSpace

    var body: some View {
        HStack(alignment: .center, spacing: SpaceTitleHeaderMetrics.spacing) {
            SpaceIconView(space: space, size: SpaceTitleHeaderMetrics.iconSize)

            Text(space.name)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private enum SpaceTitleHeaderMetrics {
    static let iconSize: CGFloat = 44
    static let spacing: CGFloat = 12
}
