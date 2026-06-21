import SwiftUI

struct PageReaderSupplementaryPanelView: View {
    @Bindable var viewModel: PageReaderViewModel

    let panel: PageReaderPanel
    let pageID: String
    let tableOfContentsItems: [PageReaderTableOfContentsItem]
    let selectHeading: (PageReaderTableOfContentsItem) -> Void
    let markInlineCommentResolved: (String, Bool) async -> Void
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
            case .comments:
                PageReaderCommentsPanelView(
                    viewModel: viewModel,
                    pageID: pageID,
                    markInlineCommentResolved: markInlineCommentResolved
                )
            case .tableOfContents:
                PageReaderTableOfContentsPanelView(
                    items: tableOfContentsItems,
                    select: selectHeading
                )
            }
        }
        .padding()
        .frame(minWidth: 280, idealWidth: 340, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
