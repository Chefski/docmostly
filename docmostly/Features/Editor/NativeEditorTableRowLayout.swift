import SwiftUI

struct NativeEditorTableRowLayout: Layout {
    let columnWidths: [CGFloat]
    var minimumHeight: CGFloat = NativeEditorTableLayout.rowMinimumHeight

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let widths = resolvedColumnWidths(for: subviews.count)
        let rowHeight = zip(subviews, widths).reduce(minimumHeight) { height, element in
            let (subview, width) = element
            return max(
                height,
                subview.sizeThatFits(.init(width: width, height: nil)).height
            )
        }

        return CGSize(width: widths.reduce(0, +), height: rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let widths = resolvedColumnWidths(for: subviews.count)
        var horizontalOffset = bounds.minX

        for (subview, width) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: horizontalOffset, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: width, height: bounds.height)
            )
            horizontalOffset += width
        }
    }

    private func resolvedColumnWidths(for subviewCount: Int) -> [CGFloat] {
        if columnWidths.count >= subviewCount {
            return Array(columnWidths.prefix(subviewCount))
        }

        return columnWidths + Array(
            repeating: NativeEditorTableLayout.minimumColumnWidth,
            count: subviewCount - columnWidths.count
        )
    }
}
