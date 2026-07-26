import SwiftUI

struct NativeEditorNestedDocumentView: View {
    @State private var viewModel: NativeRichEditorViewModel
    @FocusState private var focusedField: NativeEditorFocus?

    let target: NativeEditorNestedContentTarget
    let content: [ProseMirrorNode]
    let serverURLString: String?
    let presenceProjection: NativeEditorRemotePresenceProjection?
    let presenceScope: [NativeEditorRemotePresenceScope]
    let update: ([ProseMirrorNode]) -> Void

    init(
        blockID: UUID,
        target: NativeEditorNestedContentTarget,
        content: [ProseMirrorNode],
        serverURLString: String?,
        presenceProjection: NativeEditorRemotePresenceProjection? = nil,
        presenceScope: [NativeEditorRemotePresenceScope] = [],
        update: @escaping ([ProseMirrorNode]) -> Void
    ) {
        let model = NativeRichEditorViewModel(pageID: "nested-\(blockID.uuidString)")
        model.document = NativeEditorDocument(
            proseMirrorDocument: ProseMirrorDocument(content: content)
        )
        model.lastSavedDocument = model.document
        self.target = target
        self.content = content
        self.serverURLString = serverURLString
        self.presenceProjection = presenceProjection
        self.presenceScope = presenceScope
        self.update = update
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        NativeEditorBodyView(
            viewModel: viewModel,
            focusedField: $focusedField,
            serverURLString: serverURLString,
            slashCommandFilter: permitsCommand,
            showsTitle: false,
            showsCollaborationStatus: false,
            presenceProjection: presenceProjection,
            presenceScope: presenceScope
        )
        .onChange(of: viewModel.document) { previousDocument, updatedDocument in
            guard previousDocument != updatedDocument,
                  updatedDocument.proseMirrorDocument.content != content else {
                return
            }
            update(updatedDocument.proseMirrorDocument.content)
        }
        .onChange(of: content) { _, updatedContent in
            guard viewModel.document.proseMirrorDocument.content != updatedContent else { return }
            let updatedDocument = NativeEditorDocument(
                proseMirrorDocument: ProseMirrorDocument(content: updatedContent)
            )
            viewModel.document = updatedDocument
            viewModel.lastSavedDocument = updatedDocument
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Nested block content")
    }

    private func permitsCommand(_ command: NativeEditorCommand) -> Bool {
        guard target.permitsSyncedBlocks == false else { return true }
        return switch command {
        case .syncedBlock, .baseInline, .kanban:
            false
        default:
            true
        }
    }
}

struct NativeEditorNestedDocumentPreview: View {
    let content: [ProseMirrorNode]
    let pageID: String
    let spaceID: String?
    let serverURLString: String?

    var body: some View {
        let document = NativeEditorDocument(
            proseMirrorDocument: ProseMirrorDocument(content: content)
        )

        VStack(alignment: .leading, spacing: 6) {
            ForEach(document.blocks) { block in
                HStack(alignment: .top, spacing: 8) {
                    if NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: block.kind) {
                        NativeEditorBlockPrefix(block: .constant(block), allowsTaskToggle: false)
                            .frame(width: 24, alignment: .center)
                    }

                    NativeEditorRichBlockPreviewView(
                        block: block,
                        pageID: pageID,
                        spaceID: spaceID,
                        serverURLString: serverURLString
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(block.indentLevel) * 22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
