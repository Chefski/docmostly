import SwiftUI

struct NativeEditorRichBlockPreviewView: View {
    let block: NativeEditorBlock
    var tableActions: NativeEditorTableEditingActions?
    var richBlockActions: NativeEditorRichBlockEditingActions?

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
            Divider()
                .padding(.vertical)
                .accessibilityLabel("Divider")
        case .table(let table):
            previewShell(
                systemImage: "tablecells",
                title: "Table",
                subtitle: "\(table.rows.count) rows, \(table.columnCount) columns"
            ) {
                if let tableActions {
                    NativeEditorTableEditor(blockID: block.id, table: table, actions: tableActions)
                } else {
                    NativeEditorTablePreview(table: table)
                }
            }
        case .image(let media):
            previewShell(systemImage: "photo", title: "Image", subtitle: media.alternativeText ?? media.source)
        case .video(let media):
            previewShell(systemImage: "play.rectangle", title: "Video", subtitle: media.alternativeText ?? media.source)
        case .audio(let media):
            previewShell(systemImage: "waveform", title: "Audio", subtitle: media.source)
        case .pdf(let pdf):
            previewShell(
                systemImage: "doc.richtext",
                title: pdf.name ?? "PDF",
                subtitle: fileDetail(size: pdf.sizeInBytes, fallback: pdf.source)
            )
        case .attachment(let attachment):
            previewShell(
                systemImage: "paperclip",
                title: attachment.name ?? "File attachment",
                subtitle: fileDetail(size: attachment.sizeInBytes, fallback: attachment.mimeType ?? attachment.url)
            )
        case .callout(let callout):
            previewShell(
                systemImage: calloutSystemImage(for: callout.style),
                title: "\(callout.style.capitalized) callout",
                subtitle: callout.previewText
            ) {
                if let richBlockActions {
                    NativeEditorCalloutEditor(blockID: block.id, callout: callout, actions: richBlockActions)
                }
            }
        case .details(let details):
            previewShell(
                systemImage: details.isOpen ? "chevron.down.circle" : "chevron.right.circle",
                title: details.summary.isEmpty ? "Toggle block" : details.summary,
                subtitle: details.previewText
            ) {
                if let richBlockActions {
                    NativeEditorDetailsEditor(blockID: block.id, details: details, actions: richBlockActions)
                }
            }
        case .columns(let columns):
            previewShell(
                systemImage: columnsSystemImage(for: columns.columnCount),
                title: "Columns",
                subtitle: columns.previewText
            ) {
                if let richBlockActions {
                    NativeEditorColumnsEditor(blockID: block.id, columns: columns, actions: richBlockActions)
                }
            }
        case .subpages:
            previewShell(systemImage: "doc.on.doc", title: "Subpages", subtitle: "Child pages are shown by Docmost.")
        case .transclusionSource(let source):
            previewShell(
                systemImage: "arrow.trianglehead.2.clockwise",
                title: "Synced block",
                subtitle: source.previewText
            ) {
                if let richBlockActions {
                    NativeEditorTransclusionSourceEditor(blockID: block.id, source: source, actions: richBlockActions)
                }
            }
        case .transclusionReference(let reference):
            previewShell(
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                title: "Synced block reference",
                subtitle: reference.transclusionID ?? reference.sourcePageID
            ) {
                if let richBlockActions {
                    NativeEditorTransclusionReferenceEditor(
                        blockID: block.id,
                        reference: reference,
                        actions: richBlockActions
                    )
                }
            }
        case .embed(let embed):
            previewShell(
                systemImage: "rectangle.connected.to.line.below",
                title: embed.provider ?? "Embed",
                subtitle: embed.source
            ) {
                if let richBlockActions {
                    NativeEditorEmbedEditor(blockID: block.id, embed: embed, actions: richBlockActions)
                }
            }
        case .drawio(let diagram):
            previewShell(
                systemImage: "flowchart",
                title: diagram.title ?? "Draw.io diagram",
                subtitle: diagram.alternativeText ?? diagram.source
            ) {
                if let richBlockActions {
                    NativeEditorDiagramEditor(
                        blockID: block.id,
                        diagram: diagram,
                        update: richBlockActions.updateDrawio
                    )
                }
            }
        case .excalidraw(let diagram):
            previewShell(
                systemImage: "scribble.variable",
                title: diagram.title ?? "Excalidraw diagram",
                subtitle: diagram.alternativeText ?? diagram.source
            ) {
                if let richBlockActions {
                    NativeEditorDiagramEditor(
                        blockID: block.id,
                        diagram: diagram,
                        update: richBlockActions.updateExcalidraw
                    )
                }
            }
        case .mathBlock(let math):
            previewShell(systemImage: "function", title: "Math equation", subtitle: math.text) {
                if let richBlockActions {
                    NativeEditorMathBlockEditor(blockID: block.id, math: math, actions: richBlockActions)
                }
            }
        case .unsupported:
            NativeEditorUnsupportedBlockView(block: block)
        case .paragraph, .heading, .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock:
            Text(block.text)
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
        .background(.quaternary.opacity(0.24), in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(block.kind.accessibilityLabel)
    }

    private func fileDetail(size: Int?, fallback: String?) -> String? {
        guard let size else { return fallback }
        return ByteCountFormatStyle(style: .file).format(Int64(size))
    }

    private func calloutSystemImage(for style: String) -> String {
        switch style {
        case "warning":
            "exclamationmark.triangle"
        case "success":
            "checkmark.circle"
        case "danger", "error":
            "xmark.octagon"
        case "tip":
            "lightbulb"
        default:
            "info.circle"
        }
    }

    private func columnsSystemImage(for columnCount: Int) -> String {
        switch columnCount {
        case 3...:
            "rectangle.split.3x1"
        default:
            "rectangle.split.2x1"
        }
    }
}
