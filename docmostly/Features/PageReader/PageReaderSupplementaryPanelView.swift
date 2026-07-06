import SwiftUI

struct PageReaderSupplementaryPanelView: View {
    @Bindable var viewModel: PageReaderViewModel

    let panel: PageReaderPanel
    let editorViewModel: NativeRichEditorViewModel
    let pageID: String
    let canEdit: Bool
    let hasPageRestriction: Bool
    let workspaceSharingDisabled: Bool
    let spaceSharingDisabled: Bool
    let publicShareURL: URL?
    let serverURLString: String
    let tableOfContentsItems: [PageReaderTableOfContentsItem]
    let selectHeading: (PageReaderTableOfContentsItem) -> Void
    let markInlineCommentResolved: (String, Bool) async -> Void
    let removeInlineComment: (String) async -> Void
    let loadSharingState: () async -> Void
    let setPublicSharing: (Bool) async -> Void
    let updateShareOptions: (Bool?, Bool?) async -> Void
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(panel.title)
                    .font(.headline)

                Spacer(minLength: 0)

                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
            }

            Divider()

            switch panel {
            case .details:
                PageReaderDetailsPanelView(
                    viewModel: viewModel,
                    editorViewModel: editorViewModel,
                    pageID: pageID,
                    canEdit: canEdit
                )
            case .comments:
                PageReaderCommentsPanelView(
                    viewModel: viewModel,
                    pageID: pageID,
                    markInlineCommentResolved: markInlineCommentResolved,
                    removeInlineComment: removeInlineComment
                )
            case .tableOfContents:
                PageReaderTableOfContentsPanelView(
                    items: tableOfContentsItems,
                    select: selectHeading
                )
            case .attachments:
                AttachmentLinksView(
                    links: viewModel.attachmentLinks,
                    serverURLString: serverURLString,
                    showsEmptyState: true
                )
            case .sharing:
                PageSharingPanelView(
                    viewModel: viewModel,
                    pageID: pageID,
                    canEdit: canEdit,
                    hasPageRestriction: hasPageRestriction,
                    workspaceSharingDisabled: workspaceSharingDisabled,
                    spaceSharingDisabled: spaceSharingDisabled,
                    publicShareURL: publicShareURL,
                    loadSharingState: loadSharingState,
                    setPublicSharing: setPublicSharing,
                    updateShareOptions: updateShareOptions
                )
            }
        }
        .padding()
        .frame(minWidth: 280, idealWidth: 340, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
