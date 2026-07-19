import Foundation

nonisolated enum NativeEditorTableFocusDirection: Sendable {
    case forward
    case backward
}

nonisolated enum NativeEditorTableFocusDestination: Equatable, Sendable {
    case cell(NativeEditorTableCellCoordinate)
    case appendRowAndFocus(NativeEditorTableCellCoordinate)
}

nonisolated enum NativeEditorTableFocusNavigation {
    static func destination(
        from coordinate: NativeEditorTableCellCoordinate,
        direction: NativeEditorTableFocusDirection,
        rowCount: Int,
        columnCount: Int
    ) -> NativeEditorTableFocusDestination? {
        guard rowCount > 0, columnCount > 0 else { return nil }
        let currentIndex = coordinate.rowIndex * columnCount + coordinate.columnIndex

        switch direction {
        case .forward:
            let nextIndex = currentIndex + 1
            if nextIndex >= rowCount * columnCount {
                return .appendRowAndFocus(
                    NativeEditorTableCellCoordinate(rowIndex: rowCount, columnIndex: 0)
                )
            }
            return .cell(
                NativeEditorTableCellCoordinate(
                    rowIndex: nextIndex / columnCount,
                    columnIndex: nextIndex % columnCount
                )
            )
        case .backward:
            guard currentIndex > 0 else { return nil }
            let previousIndex = currentIndex - 1
            return .cell(
                NativeEditorTableCellCoordinate(
                    rowIndex: previousIndex / columnCount,
                    columnIndex: previousIndex % columnCount
                )
            )
        }
    }
}
