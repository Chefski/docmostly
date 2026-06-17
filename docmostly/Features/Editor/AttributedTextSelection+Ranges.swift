import Foundation
import SwiftUI

extension AttributedTextSelection {
    func hasSelectedRanges(in text: AttributedString) -> Bool {
        switch indices(in: text) {
        case .ranges(let ranges):
            ranges.isEmpty == false
        case .insertionPoint:
            false
        }
    }
}
