import SwiftUI

struct NativeEditorCalloutEditor: View {
    let blockID: UUID
    let callout: NativeEditorCalloutBlock
    let actions: NativeEditorRichBlockEditingActions

    private let styles = ["info", "tip", "warning", "success", "error"]

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
                    .frame(width: 140)
            }

            TextField("Callout", text: textBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private var iconBinding: Binding<String> {
        Binding {
            callout.icon ?? ""
        } set: { icon in
            actions.updateCallout(blockID, callout.style, icon, callout.previewText)
        }
    }

    private var textBinding: Binding<String> {
        Binding {
            callout.previewText
        } set: { text in
            actions.updateCallout(blockID, callout.style, callout.icon, text)
        }
    }
}

struct NativeEditorDetailsEditor: View {
    let blockID: UUID
    let details: NativeEditorDetailsBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Open", isOn: openBinding)
                .toggleStyle(.switch)

            TextField("Summary", text: summaryBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)

            TextField("Details", text: bodyBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
        }
    }

    private var openBinding: Binding<Bool> {
        Binding {
            details.isOpen
        } set: { isOpen in
            actions.updateDetails(blockID, details.summary, details.previewText, isOpen)
        }
    }

    private var summaryBinding: Binding<String> {
        Binding {
            details.summary
        } set: { summary in
            actions.updateDetails(blockID, summary, details.previewText, details.isOpen)
        }
    }

    private var bodyBinding: Binding<String> {
        Binding {
            details.previewText
        } set: { body in
            actions.updateDetails(blockID, details.summary, body, details.isOpen)
        }
    }
}

struct NativeEditorColumnsEditor: View {
    let blockID: UUID
    let columns: NativeEditorColumnsBlock
    let actions: NativeEditorRichBlockEditingActions

    private let layouts = ["two_equal", "two_left_sidebar", "two_right_sidebar", "three_equal"]
    private let widthModes = NativeEditorColumnsBlock.supportedWidthModes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu(layoutTitle, systemImage: "rectangle.split.2x1") {
                    ForEach(layouts, id: \.self) { layout in
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

            Stepper("Columns: \(columnTexts.count)", value: columnCountBinding, in: 1...4)

            ForEach(columnTexts.indices, id: \.self) { index in
                TextField("Column \(index + 1)", text: columnTextBinding(index: index), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
            }
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
            var updatedTexts = columnTexts
            if count > updatedTexts.count {
                updatedTexts.append(contentsOf: repeatElement("", count: count - updatedTexts.count))
            } else if count < updatedTexts.count {
                updatedTexts.removeLast(updatedTexts.count - count)
            }
            actions.updateColumns(blockID, columns.layout, columns.widthMode, updatedTexts)
        }
    }

    private func columnTextBinding(index: Int) -> Binding<String> {
        Binding {
            columnTexts[index]
        } set: { text in
            var updatedTexts = columnTexts
            guard updatedTexts.indices.contains(index) else { return }
            updatedTexts[index] = text
            actions.updateColumns(blockID, columns.layout, columns.widthMode, updatedTexts)
        }
    }
}

struct NativeEditorTransclusionSourceEditor: View {
    let blockID: UUID
    let source: NativeEditorTransclusionSourceBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Synced block ID", text: identifierBinding)
                .docmostlyTextInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            TextField("Content", text: textBinding, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
        }
    }

    private var identifierBinding: Binding<String> {
        Binding {
            source.identifier ?? ""
        } set: { identifier in
            actions.updateTransclusionSource(blockID, identifier, source.previewText)
        }
    }

    private var textBinding: Binding<String> {
        Binding {
            source.previewText
        } set: { text in
            actions.updateTransclusionSource(blockID, source.identifier ?? "", text)
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
