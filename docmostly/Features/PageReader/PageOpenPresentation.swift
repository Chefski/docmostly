import SwiftUI

enum PageOpenPresentation: Equatable {
    case stack
    case detailColumn

    var shouldClearSelectedPageOnReaderDisappear: Bool {
        self == .stack
    }
}

extension EnvironmentValues {
    @Entry var pageOpenPresentation = PageOpenPresentation.stack
}
