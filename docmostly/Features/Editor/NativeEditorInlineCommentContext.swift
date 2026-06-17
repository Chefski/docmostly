import Foundation
import SwiftUI

struct NativeEditorInlineCommentContext: Equatable, Sendable {
    let blockID: UUID
    let selectedText: String
    let selection: AttributedTextSelection
}
