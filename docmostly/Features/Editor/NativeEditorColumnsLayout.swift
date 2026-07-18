import SwiftUI

nonisolated enum NativeEditorColumnsLayoutPolicy {
    static func weights(layout: String, explicitWidths: [Double?], count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let preset = presetWeights(layout: layout, count: count)
        return (0..<count).map { index in
            guard explicitWidths.indices.contains(index), let width = explicitWidths[index], width > 0 else {
                return preset[index]
            }
            return min(max(width, 0.25), 4)
        }
    }

    static func shouldStack(availableWidth: CGFloat, count: Int) -> Bool {
        availableWidth < CGFloat(count) * 190
    }

    private static func presetWeights(layout: String, count: Int) -> [Double] {
        let weights: [Double]
        switch layout {
        case "two_left_sidebar":
            weights = [0.65, 1.35]
        case "two_right_sidebar":
            weights = [1.35, 0.65]
        case "three_left_wide":
            weights = [1.6, 0.7, 0.7]
        case "three_right_wide":
            weights = [0.7, 0.7, 1.6]
        case "three_with_sidebars":
            weights = [0.7, 1.6, 0.7]
        default:
            weights = Array(repeating: 1, count: count)
        }
        guard weights.count == count else { return Array(repeating: 1, count: count) }
        return weights
    }
}

struct NativeEditorResponsiveColumnsLayout: Layout {
    let weights: [Double]
    var spacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.isEmpty == false else { return .zero }
        let availableWidth = proposal.width ?? 0
        if NativeEditorColumnsLayoutPolicy.shouldStack(availableWidth: availableWidth, count: subviews.count) {
            let sizes = subviews.map { $0.sizeThatFits(.init(width: availableWidth, height: nil)) }
            return CGSize(
                width: sizes.map(\.width).max() ?? availableWidth,
                height: sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0))
            )
        }

        let widths = resolvedWidths(availableWidth: availableWidth, count: subviews.count)
        let sizes = zip(subviews, widths).map { subview, width in
            subview.sizeThatFits(.init(width: width, height: nil))
        }
        return CGSize(width: availableWidth, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.isEmpty == false else { return }
        if NativeEditorColumnsLayoutPolicy.shouldStack(availableWidth: bounds.width, count: subviews.count) {
            var verticalOffset = bounds.minY
            for subview in subviews {
                let size = subview.sizeThatFits(.init(width: bounds.width, height: nil))
                subview.place(
                    at: CGPoint(x: bounds.minX, y: verticalOffset),
                    anchor: .topLeading,
                    proposal: .init(width: bounds.width, height: size.height)
                )
                verticalOffset += size.height + spacing
            }
            return
        }

        let widths = resolvedWidths(availableWidth: bounds.width, count: subviews.count)
        var horizontalOffset = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: horizontalOffset, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: width, height: bounds.height)
            )
            horizontalOffset += width + spacing
        }
    }

    private func resolvedWidths(availableWidth: CGFloat, count: Int) -> [CGFloat] {
        let availableContentWidth = max(availableWidth - spacing * CGFloat(max(count - 1, 0)), 0)
        let resolvedWeights = weights.count == count ? weights : Array(repeating: 1, count: count)
        let totalWeight = max(resolvedWeights.reduce(0, +), 1)
        return resolvedWeights.map { availableContentWidth * CGFloat($0 / totalWeight) }
    }
}
