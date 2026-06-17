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

struct NativeEditorEmbedEditor: View {
    let blockID: UUID
    let embed: NativeEditorEmbedBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("URL", text: sourceBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
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
            .textInputAutocapitalization(.never)
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
