import SwiftUI

enum PageOpenPresentation {
    case stack
    case detailColumn
}

extension EnvironmentValues {
    @Entry var pageOpenPresentation = PageOpenPresentation.stack
}
