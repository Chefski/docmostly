import SwiftUI

struct NativeEditorRichBlockPreviewView: View {
    let block: NativeEditorBlock
    var tableActions: NativeEditorTableEditingActions?

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
            )
        case .details(let details):
            previewShell(
                systemImage: details.isOpen ? "chevron.down.circle" : "chevron.right.circle",
                title: details.summary.isEmpty ? "Toggle block" : details.summary,
                subtitle: details.previewText
            )
        case .columns(let columns):
            previewShell(
                systemImage: columnsSystemImage(for: columns.columnCount),
                title: "Columns",
                subtitle: columns.previewText
            )
        case .subpages:
            previewShell(systemImage: "doc.on.doc", title: "Subpages", subtitle: "Child pages are shown by Docmost.")
        case .transclusionSource(let source):
            previewShell(
                systemImage: "arrow.trianglehead.2.clockwise",
                title: "Synced block",
                subtitle: source.previewText
            )
        case .transclusionReference(let reference):
            previewShell(
                systemImage: "arrow.trianglehead.2.clockwise.rotate.90",
                title: "Synced block reference",
                subtitle: reference.transclusionID ?? reference.sourcePageID
            )
        case .embed(let embed):
            previewShell(
                systemImage: "rectangle.connected.to.line.below",
                title: embed.provider ?? "Embed",
                subtitle: embed.source
            )
        case .drawio(let diagram):
            previewShell(
                systemImage: "flowchart",
                title: diagram.title ?? "Draw.io diagram",
                subtitle: diagram.alternativeText ?? diagram.source
            )
        case .excalidraw(let diagram):
            previewShell(
                systemImage: "scribble.variable",
                title: diagram.title ?? "Excalidraw diagram",
                subtitle: diagram.alternativeText ?? diagram.source
            )
        case .mathBlock(let math):
            previewShell(systemImage: "function", title: "Math equation", subtitle: math.text)
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

private struct NativeEditorTablePreview: View {
    let table: NativeEditorTable

    var body: some View {
        VStack(spacing: 0) {
            let visibleRows = table.rows.prefix(3)
            ForEach(visibleRows.indices, id: \.self) { rowIndex in
                let row = table.rows[rowIndex]
                HStack(spacing: 0) {
                    let visibleCells = row.cells.prefix(3)
                    ForEach(visibleCells.indices, id: \.self) { cellIndex in
                        let cell = row.cells[cellIndex]
                        Text(cell.plainText.isEmpty ? " " : cell.plainText)
                            .font(cell.isHeader ? .subheadline.bold() : .subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(cell.isHeader ? Color.secondary.opacity(0.12) : Color.clear)
                            .overlay(alignment: .trailing) {
                                Divider()
                            }
                    }
                }
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct NativeEditorTableEditor: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        tableRow(rowIndex)
                    }

                    tableColumnControls
                }
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func tableRow(_ rowIndex: Int) -> some View {
        GridRow {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                if let cell = cell(rowIndex: rowIndex, columnIndex: columnIndex) {
                    tableCell(cell, rowIndex: rowIndex, columnIndex: columnIndex)
                } else {
                    missingCell
                }
            }

            rowControls(rowIndex)
        }
    }

    private func tableCell(
        _ cell: NativeEditorTableCell,
        rowIndex: Int,
        columnIndex: Int
    ) -> some View {
        TextField("Cell", text: cellBinding(rowIndex: rowIndex, columnIndex: columnIndex), axis: .vertical)
            .textFieldStyle(.plain)
            .font(cell.isHeader ? .subheadline.bold() : .subheadline)
            .foregroundStyle(.primary)
            .lineLimit(3)
            .frame(width: 148, alignment: .leading)
            .frame(minHeight: 44, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(cellBackground(for: cell))
            .overlay(alignment: .trailing) {
                Divider()
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
    }

    private func rowControls(_ rowIndex: Int) -> some View {
        HStack(spacing: 2) {
            Button("Add Row Below", systemImage: "plus") {
                actions.insertRowBelow(blockID, rowIndex)
            }
            .accessibilityLabel("Add row below")

            Button("Delete Row", systemImage: "trash", role: .destructive) {
                actions.deleteRow(blockID, rowIndex)
            }
            .accessibilityLabel("Delete row")
            .disabled(table.rows.count <= 1)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .frame(width: 72)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var tableColumnControls: some View {
        GridRow {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                HStack(spacing: 2) {
                    Button("Add Column After", systemImage: "plus") {
                        actions.insertColumnAfter(blockID, columnIndex)
                    }
                    .accessibilityLabel("Add column after")

                    Button("Delete Column", systemImage: "trash", role: .destructive) {
                        actions.deleteColumn(blockID, columnIndex)
                    }
                    .accessibilityLabel("Delete column")
                    .disabled(columnCount <= 1)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .frame(width: 148)
                .frame(minHeight: 36)
                .background(Color.secondary.opacity(0.05))
                .overlay(alignment: .trailing) {
                    Divider()
                }
            }

            Color.clear
                .frame(width: 72)
                .frame(minHeight: 36)
                .background(Color.secondary.opacity(0.05))
        }
    }

    private var missingCell: some View {
        Text(" ")
            .frame(width: 148)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(0.04))
            .overlay(alignment: .trailing) {
                Divider()
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
    }

    private var columnCount: Int {
        max(table.columnCount, 1)
    }

    private func cell(rowIndex: Int, columnIndex: Int) -> NativeEditorTableCell? {
        guard table.rows.indices.contains(rowIndex),
              table.rows[rowIndex].cells.indices.contains(columnIndex) else {
            return nil
        }

        return table.rows[rowIndex].cells[columnIndex]
    }

    private func cellBinding(rowIndex: Int, columnIndex: Int) -> Binding<String> {
        Binding {
            cell(rowIndex: rowIndex, columnIndex: columnIndex)?.plainText ?? ""
        } set: { text in
            actions.updateCell(blockID, rowIndex, columnIndex, text)
        }
    }

    private func cellBackground(for cell: NativeEditorTableCell) -> Color {
        cell.isHeader ? Color.secondary.opacity(0.12) : Color.clear
    }
}
