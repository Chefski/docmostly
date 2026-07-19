import Foundation

nonisolated enum NativeEditorNestedContentTarget: Equatable, Hashable, Sendable {
    case callout
    case detailsContent
    case column(index: Int)
    case transclusionSource
}

nonisolated extension NativeEditorNestedContentTarget {
    var permitsSyncedBlocks: Bool {
        switch self {
        case .transclusionSource:
            false
        case .callout, .detailsContent, .column:
            true
        }
    }
}
