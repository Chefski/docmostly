import Foundation

struct NativeEditorRichBlockEditingActions {
    let updateCallout: (UUID, String, String?, String) -> Void
    let updateDetails: (UUID, String, String, Bool) -> Void
    let updateEmbed: (UUID, String, String) -> Void
    let updateDrawio: (UUID, String, String, String) -> Void
    let updateExcalidraw: (UUID, String, String, String) -> Void
    let updateMathBlock: (UUID, String) -> Void
}
