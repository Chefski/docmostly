import SwiftUI

struct NativeEditorAttachmentToolbarGroup: View {
    let isUploading: Bool
    let importAttachment: (NativeEditorAttachmentImportKind) -> Void

    var body: some View {
        Menu {
            ForEach(NativeEditorAttachmentImportKind.allCases) { importKind in
                Button {
                    importAttachment(importKind)
                } label: {
                    Label(importKind.title, systemImage: importKind.systemImage)
                }
            }
        } label: {
            if isUploading {
                Label("Uploading", systemImage: "arrow.up.doc")
            } else {
                Label("Attach", systemImage: "paperclip")
            }
        }
        .accessibilityLabel(isUploading ? "Uploading attachment" : "Attach")
        .disabled(isUploading)
    }
}
