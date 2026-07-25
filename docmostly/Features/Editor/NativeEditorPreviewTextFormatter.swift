import SwiftUI

enum NativeEditorPreviewTextFormatter {
    static func text(_ source: AttributedString, for kind: NativeEditorBlockKind) -> AttributedString {
        var result = source
        guard case .heading = kind else { return result }

        let stronglyEmphasizedRanges = result.runs.compactMap { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true ? run.range : nil
        }
        for range in stronglyEmphasizedRanges {
            result[range].font = kind.stronglyEmphasizedEditorFont
        }
        return result
    }
}
