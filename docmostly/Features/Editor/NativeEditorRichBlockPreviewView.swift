import SwiftUI

struct NativeEditorRichBlockPreviewView: View {
    let block: NativeEditorBlock
    var tableActions: NativeEditorTableEditingActions?
    var richBlockActions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    var serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var presenceScope: [NativeEditorRemotePresenceScope] = []
    var presenceBlockIndex: Int?

    var body: some View {
        switch block.kind {
        case .pageBreak:
            Label("Page break", systemImage: "doc.text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .overlay {
                    Divider()
                }
        case .divider:
            NativeEditorHorizontalRuleView()
        case .table(let table):
            if let tableActions {
                NativeEditorTableEditor(blockID: block.id, table: table, actions: tableActions)
            } else {
                NativeEditorTablePreview(table: table)
            }
        case .image(let media):
            NativeEditorImageBlockView(
                blockID: block.id,
                media: media,
                serverURLString: serverURLString,
                actions: richBlockActions
            )
        case .video(let media):
            previewShell(
                systemImage: "play.rectangle",
                title: "Video",
                subtitle: media.alternativeText ?? media.title ?? media.source
            ) {
                if let richBlockActions {
                    NativeEditorMediaBlockEditor(blockID: block.id, media: media, actions: richBlockActions)
                }
            }
        case .audio(let media):
            previewShell(systemImage: "waveform", title: "Audio", subtitle: media.title ?? media.source) {
                if let richBlockActions {
                    NativeEditorMediaBlockEditor(blockID: block.id, media: media, actions: richBlockActions)
                }
            }
        case .pdf(let pdf):
            previewShell(
                systemImage: "doc.richtext",
                title: pdf.name ?? "PDF",
                subtitle: fileDetail(size: pdf.sizeInBytes, fallback: pdf.source)
            ) {
                if let richBlockActions {
                    NativeEditorPDFBlockEditor(blockID: block.id, pdf: pdf, actions: richBlockActions)
                }
            }
        case .attachment(let attachment):
            previewShell(
                systemImage: "paperclip",
                title: attachment.name ?? "File attachment",
                subtitle: fileDetail(size: attachment.sizeInBytes, fallback: attachment.mimeType ?? attachment.url)
            ) {
                if let richBlockActions {
                    NativeEditorAttachmentBlockEditor(
                        blockID: block.id,
                        attachment: attachment,
                        actions: richBlockActions
                    )
                }
            }
        case .callout(let callout):
            NativeEditorCalloutBlockView(
                blockID: block.id,
                callout: callout,
                content: calloutContent(for: callout),
                actions: richBlockActions,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString,
                presenceProjection: presenceProjection,
                presenceScope: nestedPresenceScope(for: .callout)
            )
        case .details(let details):
            NativeEditorDetailsBlockView(
                blockID: block.id,
                details: details,
                bodyContent: detailsBodyContent(for: details),
                actions: richBlockActions,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString,
                presenceProjection: presenceProjection,
                presenceScope: nestedPresenceScope(for: .detailsContent)
            )
        case .columns(let columns):
            NativeEditorColumnsBlockView(
                blockID: block.id,
                columns: columns,
                columnNodes: columnNodes(for: columns),
                actions: richBlockActions,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString,
                presenceProjection: presenceProjection,
                parentPresenceScope: presenceScope,
                presenceBlockIndex: presenceBlockIndex
            )
        case .subpages:
            previewShell(systemImage: "doc.on.doc", title: "Subpages", subtitle: nil) {
                NativeEditorSubpagesView(pageID: pageID, spaceID: spaceID)
            }
        case .transclusionSource(let source):
            NativeEditorTransclusionSourceBlockView(
                blockID: block.id,
                source: source,
                content: block.rawNode?.content ?? [],
                actions: richBlockActions,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString,
                presenceProjection: presenceProjection,
                presenceScope: nestedPresenceScope(for: .transclusionSource)
            )
        case .transclusionReference(let reference):
            NativeEditorSyncedReferenceView(
                reference: reference,
                pageID: pageID,
                spaceID: spaceID,
                serverURLString: serverURLString
            )
        case .base(let base):
            previewShell(
                systemImage: "tablecells",
                title: base.previewText,
                subtitle: base.pageID ?? "Base page pending"
            )
        case .embed(let embed):
            NativeEditorEmbedBlockView(blockID: block.id, embed: embed, actions: richBlockActions)
        case .drawio(let diagram):
            NativeEditorDiagramBlockView(
                blockID: block.id,
                diagram: diagram,
                title: "Draw.io diagram",
                systemImage: "flowchart",
                serverURLString: serverURLString,
                update: richBlockActions?.updateDrawio
            )
        case .excalidraw(let diagram):
            NativeEditorDiagramBlockView(
                blockID: block.id,
                diagram: diagram,
                title: "Excalidraw diagram",
                systemImage: "scribble.variable",
                serverURLString: serverURLString,
                update: richBlockActions?.updateExcalidraw
            )
        case .mathBlock(let math):
            NativeEditorMathBlockView(blockID: block.id, math: math, actions: richBlockActions)
        case .unsupported:
            NativeEditorUnsupportedBlockView(block: block)
        case .paragraph, .heading, .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock:
            Text(NativeEditorPreviewTextFormatter.text(block.text, for: block.kind))
                .font(block.kind.editorFont)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func previewShell<Content: View>(
        systemImage: String,
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .glassEffect(.regular.tint(.white.opacity(0.08)), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(block.kind.accessibilityLabel)
    }

    private func fileDetail(size: Int?, fallback: String?) -> String? {
        guard let size else { return fallback }
        return ByteCountFormatStyle(style: .file).format(Int64(size))
    }

    private func detailsBodyContent(for details: NativeEditorDetailsBlock) -> [ProseMirrorNode] {
        let node = block.rawNode ?? NativeEditorRichBlockNodeFactory.detailsNode(from: details)
        return node.content?.first(where: { $0.type == "detailsContent" })?.content ?? []
    }

    private func calloutContent(for callout: NativeEditorCalloutBlock) -> [ProseMirrorNode] {
        block.rawNode?.content ?? NativeEditorRichBlockNodeFactory.calloutNode(from: callout).content ?? []
    }

    private func columnNodes(for columns: NativeEditorColumnsBlock) -> [ProseMirrorNode] {
        let node = block.rawNode ?? NativeEditorRichBlockNodeFactory.columnsNode(from: columns)
        return (node.content ?? []).filter { $0.type == "column" }
    }

    private func nestedPresenceScope(
        for target: NativeEditorNestedContentTarget
    ) -> [NativeEditorRemotePresenceScope] {
        guard let presenceBlockIndex else { return presenceScope }
        return presenceScope + [NativeEditorRemotePresenceScope(
            containerBlockIndex: presenceBlockIndex,
            target: target
        )]
    }

}
