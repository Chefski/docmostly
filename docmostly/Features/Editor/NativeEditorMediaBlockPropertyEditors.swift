import SwiftUI

struct NativeEditorMediaBlockEditor: View {
    let blockID: UUID
    let media: NativeEditorMediaBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Source", text: sourceBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

            TextField("Alt text", text: alternativeTextBinding)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Width", text: widthBinding)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Height", text: heightBinding)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Align", text: alignmentBinding)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var sourceBinding: Binding<String> {
        Binding {
            media.source ?? ""
        } set: { source in
            update(source: source)
        }
    }

    private var alternativeTextBinding: Binding<String> {
        Binding {
            media.alternativeText ?? ""
        } set: { alternativeText in
            update(alternativeText: alternativeText)
        }
    }

    private var widthBinding: Binding<String> {
        Binding {
            media.width ?? ""
        } set: { width in
            update(width: width)
        }
    }

    private var heightBinding: Binding<String> {
        Binding {
            media.height ?? ""
        } set: { height in
            update(height: height)
        }
    }

    private var alignmentBinding: Binding<String> {
        Binding {
            media.alignment ?? ""
        } set: { alignment in
            update(alignment: alignment)
        }
    }

    private func update(
        source: String? = nil,
        alternativeText: String? = nil,
        width: String? = nil,
        height: String? = nil,
        alignment: String? = nil
    ) {
        actions.updateMediaBlock(
            blockID,
            NativeEditorMediaBlockUpdate(
                source: source ?? media.source ?? "",
                alternativeText: alternativeText ?? media.alternativeText ?? "",
                width: width ?? media.width ?? "",
                height: height ?? media.height ?? "",
                alignment: alignment ?? media.alignment ?? ""
            )
        )
    }
}

struct NativeEditorPDFBlockEditor: View {
    let blockID: UUID
    let pdf: NativeEditorPDFBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Source", text: sourceBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

            TextField("Name", text: nameBinding)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Width", text: widthBinding)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                TextField("Height", text: heightBinding)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var sourceBinding: Binding<String> {
        Binding {
            pdf.source ?? ""
        } set: { source in
            update(source: source)
        }
    }

    private var nameBinding: Binding<String> {
        Binding {
            pdf.name ?? ""
        } set: { name in
            update(name: name)
        }
    }

    private var widthBinding: Binding<String> {
        Binding {
            pdf.width ?? ""
        } set: { width in
            update(width: width)
        }
    }

    private var heightBinding: Binding<String> {
        Binding {
            pdf.height ?? ""
        } set: { height in
            update(height: height)
        }
    }

    private func update(source: String? = nil, name: String? = nil, width: String? = nil, height: String? = nil) {
        actions.updatePDFBlock(
            blockID,
            source ?? pdf.source ?? "",
            name ?? pdf.name ?? "",
            width ?? pdf.width ?? "",
            height ?? pdf.height ?? ""
        )
    }
}

struct NativeEditorAttachmentBlockEditor: View {
    let blockID: UUID
    let attachment: NativeEditorAttachmentBlock
    let actions: NativeEditorRichBlockEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("URL", text: urlBinding)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)

            TextField("Name", text: nameBinding)
                .textFieldStyle(.roundedBorder)

            TextField("MIME type", text: mimeBinding)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var urlBinding: Binding<String> {
        Binding {
            attachment.url ?? ""
        } set: { url in
            update(url: url)
        }
    }

    private var nameBinding: Binding<String> {
        Binding {
            attachment.name ?? ""
        } set: { name in
            update(name: name)
        }
    }

    private var mimeBinding: Binding<String> {
        Binding {
            attachment.mimeType ?? ""
        } set: { mimeType in
            update(mimeType: mimeType)
        }
    }

    private func update(url: String? = nil, name: String? = nil, mimeType: String? = nil) {
        actions.updateAttachmentBlock(
            blockID,
            url ?? attachment.url ?? "",
            name ?? attachment.name ?? "",
            mimeType ?? attachment.mimeType ?? ""
        )
    }
}
