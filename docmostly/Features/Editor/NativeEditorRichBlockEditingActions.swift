import Foundation

struct NativeEditorRichBlockEditingActions {
    let updateCallout: (UUID, String, String?, String) -> Void
    let updateDetails: (UUID, String, String, Bool) -> Void
    let updateColumns: (UUID, String, String, [String]) -> Void
    let updateTransclusionSource: (UUID, String, String) -> Void
    let updateTransclusionReference: (UUID, String, String) -> Void
    let updateMediaBlock: (UUID, NativeEditorMediaBlockUpdate) -> Void
    let updatePDFBlock: (UUID, String, String, String, String) -> Void
    let updateAttachmentBlock: (UUID, String, String, String) -> Void
    let updateEmbed: (UUID, String, String) -> Void
    let updateDrawio: (UUID, String, String, String) -> Void
    let updateExcalidraw: (UUID, String, String, String) -> Void
    let updateMathBlock: (UUID, String) -> Void
}
