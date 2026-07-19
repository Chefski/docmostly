import SwiftUI

struct NativeEditorTableSelectionFill: View {
    let selection: NativeEditorTableSelection?
    let rowIndex: Int
    let columnIndex: Int

    var body: some View {
        if selection?.contains(rowIndex: rowIndex, columnIndex: columnIndex) == true {
            switch selection?.kind {
            case .row where columnIndex == 0:
                indicator(width: 4, height: nil, alignment: .leading)
            case .column where rowIndex == 0:
                indicator(width: nil, height: 4, alignment: .top)
            default:
                EmptyView()
            }
        }
    }

    private func indicator(width: CGFloat?, height: CGFloat?, alignment: Alignment) -> some View {
        Rectangle()
            .fill(NativeEditorTableLayout.selectionAccent)
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .allowsHitTesting(false)
    }
}
