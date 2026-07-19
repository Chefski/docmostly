import SwiftUI

struct NativeEditorColumnContent: View {
    let blockID: UUID
    let index: Int
    let content: [ProseMirrorNode]
    let actions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var parentPresenceScope: [NativeEditorRemotePresenceScope] = []
    var presenceBlockIndex: Int?

    var body: some View {
        Group {
            if let actions {
                NativeEditorNestedDocumentView(
                    blockID: blockID,
                    target: .column(index: index),
                    content: content,
                    serverURLString: serverURLString,
                    presenceProjection: presenceProjection,
                    presenceScope: columnPresenceScope
                ) { updatedContent in
                    actions.updateNestedContent(blockID, .column(index: index), updatedContent)
                }
            } else {
                NativeEditorNestedDocumentPreview(
                    content: content,
                    pageID: pageID,
                    spaceID: spaceID,
                    serverURLString: serverURLString
                )
            }
        }
        .padding(10)
        .frame(minHeight: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.12), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Column \(index + 1)")
    }

    private var columnPresenceScope: [NativeEditorRemotePresenceScope] {
        guard let presenceBlockIndex else { return parentPresenceScope }
        return parentPresenceScope + [NativeEditorRemotePresenceScope(
            containerBlockIndex: presenceBlockIndex,
            target: .column(index: index)
        )]
    }
}
