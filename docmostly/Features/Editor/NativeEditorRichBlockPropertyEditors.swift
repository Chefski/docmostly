import SwiftUI

struct NativeEditorCalloutEditor: View {
    let blockID: UUID
    let callout: NativeEditorCalloutBlock
    let actions: NativeEditorRichBlockEditingActions

    private let styles = ["default", "info", "note", "success", "warning", "danger"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu(callout.style.capitalized, systemImage: "tag") {
                    ForEach(styles, id: \.self) { style in
                        Button(style.capitalized) {
                            actions.updateCallout(blockID, style, callout.icon, callout.previewText)
                        }
                    }
                }

                TextField("Icon", text: iconBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                    .accessibilityLabel("Callout icon")
            }
        }
    }

    private var iconBinding: Binding<String> {
        Binding {
            callout.icon ?? ""
        } set: { icon in
            actions.updateCallout(blockID, callout.style, icon, callout.previewText)
        }
    }

}

struct NativeEditorDetailsEditor: View {
    let blockID: UUID
    let details: NativeEditorDetailsBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Summary", text: summaryBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

        }
    }

    private var summaryBinding: Binding<String> {
        Binding {
            details.summary
        } set: { summary in
            actions.updateDetails(blockID, summary, details.previewText, details.isOpen)
        }
    }

}

struct NativeEditorColumnsEditor: View {
    let blockID: UUID
    let columns: NativeEditorColumnsBlock
    let actions: NativeEditorRichBlockEditingActions

    private let layouts = NativeEditorColumnsBlock.supportedLayouts
    private let widthModes = NativeEditorColumnsBlock.supportedWidthModes
    private let columnCountRange = 2...NativeEditorColumnsBlock.maximumColumnCount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu(layoutTitle, systemImage: "rectangle.split.2x1") {
                    ForEach(supportedLayouts, id: \.self) { layout in
                        Button(layout.replacing("_", with: " ").capitalized) {
                            actions.updateColumns(blockID, layout, columns.widthMode, columnTexts)
                        }
                    }
                }

                Menu(columns.widthMode.capitalized, systemImage: "arrow.left.and.right") {
                    ForEach(widthModes, id: \.self) { widthMode in
                        Button(widthMode.capitalized) {
                            actions.updateColumns(blockID, columns.layout, widthMode, columnTexts)
                        }
                    }
                }
            }

            Stepper("Columns: \(columnTexts.count)", value: columnCountBinding, in: columnCountRange)

            ForEach(columnTexts.indices, id: \.self) { index in
                HStack {
                    Text("Column \(index + 1) width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: columnWidthBinding(index: index), in: 0.25...4, step: 0.05)
                        .accessibilityLabel("Column \(index + 1) width")
                }
            }

            Button("Reset Column Widths", systemImage: "arrow.counterclockwise") {
                for index in columnTexts.indices {
                    actions.updateColumnWidth(blockID, index, nil)
                }
            }
            .buttonStyle(.borderless)
        }
    }

    private var layoutTitle: String {
        columns.layout.replacing("_", with: " ").capitalized
    }

    private var columnTexts: [String] {
        if columns.columnTexts.isEmpty == false {
            return columns.columnTexts
        }
        return [columns.previewText]
    }

    private var columnCountBinding: Binding<Int> {
        Binding {
            columnTexts.count
        } set: { count in
            actions.setColumnCount(blockID, count)
        }
    }

    private var supportedLayouts: [String] {
        let prefix = switch columnTexts.count {
        case 2: "two_"
        case 3: "three_"
        case 4: "four_"
        default: "five_"
        }
        return layouts.filter { $0.hasPrefix(prefix) }
    }

    private func columnWidthBinding(index: Int) -> Binding<Double> {
        Binding {
            guard columns.normalizedColumnWidths.indices.contains(index) else { return 1 }
            return columns.normalizedColumnWidths[index] ?? 1
        } set: { width in
            actions.updateColumnWidth(blockID, index, width)
        }
    }
}

struct NativeEditorTransclusionSourceEditor: View {
    let blockID: UUID
    let source: NativeEditorTransclusionSourceBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Synced block ID") {
                Text(source.identifier ?? "Pending")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}

struct NativeEditorTransclusionReferenceEditor: View {
    let blockID: UUID
    let reference: NativeEditorTransclusionReferenceBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Source page ID", text: sourcePageBinding)
                .docmostlyTextInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            TextField("Synced block ID", text: transclusionBinding)
                .docmostlyTextInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var sourcePageBinding: Binding<String> {
        Binding {
            reference.sourcePageID ?? ""
        } set: { sourcePageID in
            actions.updateTransclusionReference(blockID, sourcePageID, reference.transclusionID ?? "")
        }
    }

    private var transclusionBinding: Binding<String> {
        Binding {
            reference.transclusionID ?? ""
        } set: { transclusionID in
            actions.updateTransclusionReference(blockID, reference.sourcePageID ?? "", transclusionID)
        }
    }
}

struct NativeEditorEmbedEditor: View {
    let blockID: UUID
    let embed: NativeEditorEmbedBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("URL", text: sourceBinding)
                .docmostlyTextInputAutocapitalization(.never)
                .docmostlyKeyboardType(.url)
                .textFieldStyle(.roundedBorder)

            TextField("Provider", text: providerBinding)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var sourceBinding: Binding<String> {
        Binding {
            embed.source ?? ""
        } set: { source in
            actions.updateEmbed(blockID, source, embed.provider ?? "")
        }
    }

    private var providerBinding: Binding<String> {
        Binding {
            embed.provider ?? ""
        } set: { provider in
            actions.updateEmbed(blockID, embed.source ?? "", provider)
        }
    }
}

struct NativeEditorMathBlockEditor: View {
    let blockID: UUID
    let math: NativeEditorMathBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        TextField("Expression", text: expressionBinding, axis: .vertical)
            .docmostlyTextInputAutocapitalization(.never)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
    }

    private var expressionBinding: Binding<String> {
        Binding {
            math.text
        } set: { text in
            actions.updateMathBlock(blockID, text)
        }
    }
}

struct NativeEditorDiagramEditor: View {
    let blockID: UUID
    let diagram: NativeEditorDiagramBlock
    let update: (UUID, String, String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Source", text: sourceBinding)
                .docmostlyTextInputAutocapitalization(.never)
                .docmostlyKeyboardType(.url)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Title", text: titleBinding)
                    .textFieldStyle(.roundedBorder)

                TextField("Alt", text: alternativeTextBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var sourceBinding: Binding<String> {
        Binding {
            diagram.source ?? ""
        } set: { source in
            update(blockID, source, diagram.title ?? "", diagram.alternativeText ?? "")
        }
    }

    private var titleBinding: Binding<String> {
        Binding {
            diagram.title ?? ""
        } set: { title in
            update(blockID, diagram.source ?? "", title, diagram.alternativeText ?? "")
        }
    }

    private var alternativeTextBinding: Binding<String> {
        Binding {
            diagram.alternativeText ?? ""
        } set: { alternativeText in
            update(blockID, diagram.source ?? "", diagram.title ?? "", alternativeText)
        }
    }
}
