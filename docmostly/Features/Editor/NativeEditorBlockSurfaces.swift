import SwiftUI

struct NativeEditorBlockTextSurface<Content: View>: View {
    let kind: NativeEditorBlockKind
    let content: Content

    init(kind: NativeEditorBlockKind, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.content = content()
    }

    var body: some View {
        switch kind {
        case .blockquote:
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.tertiary)
                    .frame(width: 3)

                content
                    .foregroundStyle(.secondary)
                    .opacity(0.78)
                    .padding(.vertical, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .codeBlock(let language):
            VStack(alignment: .leading, spacing: 8) {
                if let language, language.isEmpty == false {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }

                content
                    .font(.body.monospaced())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.28), in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 1)
            }
        default:
            content
        }
    }
}

struct NativeEditorHorizontalRuleView: View {
    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Divider")
    }
}

struct NativeEditorCalloutBlockView: View {
    let blockID: UUID
    let callout: NativeEditorCalloutBlock
    let content: [ProseMirrorNode]
    let actions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var presenceScope: [NativeEditorRemotePresenceScope] = []

    var body: some View {
        let presentation = NativeEditorCalloutPresentation(style: callout.style)

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                NativeEditorCalloutIcon(presentation: presentation, customIcon: callout.icon)
                    .padding(.top, 1)

                Group {
                    if let actions {
                        NativeEditorNestedDocumentView(
                            blockID: blockID,
                            target: .callout,
                            content: content,
                            serverURLString: serverURLString,
                            presenceProjection: presenceProjection,
                            presenceScope: presenceScope
                        ) { updatedContent in
                            actions.updateNestedContent(blockID, .callout, updatedContent)
                        }
                    } else {
                        NativeEditorNestedDocumentPreview(
                            content: content,
                            pageID: pageID,
                            spaceID: spaceID,
                            serverURLString: serverURLString
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let actions {
                NativeEditorCalloutEditor(blockID: blockID, callout: callout, actions: actions)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(presentation.tint.opacity(0.14), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(presentation.tint.opacity(0.28), lineWidth: 1)
        }
        .glassEffect(.regular.tint(presentation.tint.opacity(0.16)), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.title) callout")
    }
}

struct NativeEditorDetailsBlockView: View {
    let blockID: UUID
    let details: NativeEditorDetailsBlock
    let bodyContent: [ProseMirrorNode]
    let actions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var presenceScope: [NativeEditorRemotePresenceScope] = []
    @State private var transientIsOpen: Bool

    init(
        blockID: UUID,
        details: NativeEditorDetailsBlock,
        bodyContent: [ProseMirrorNode],
        actions: NativeEditorRichBlockEditingActions?,
        pageID: String,
        spaceID: String?,
        serverURLString: String?,
        presenceProjection: NativeEditorRemotePresenceProjection? = nil,
        presenceScope: [NativeEditorRemotePresenceScope] = []
    ) {
        self.blockID = blockID
        self.details = details
        self.bodyContent = bodyContent
        self.actions = actions
        self.pageID = pageID
        self.spaceID = spaceID
        self.serverURLString = serverURLString
        self.presenceProjection = presenceProjection
        self.presenceScope = presenceScope
        _transientIsOpen = State(initialValue: details.isOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: toggleOpen) {
                HStack(spacing: 8) {
                    Image(systemName: isOpen ? "chevron.down.circle" : "chevron.right.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)

                    Text(details.summary.isEmpty ? "Toggle block" : details.summary)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOpen ? "Collapse toggle block" : "Expand toggle block")

            if isOpen {
                if let actions {
                    NativeEditorDetailsEditor(blockID: blockID, details: details, actions: actions)
                        .padding(.top, 2)

                    NativeEditorNestedDocumentView(
                        blockID: blockID,
                        target: .detailsContent,
                        content: bodyContent,
                        serverURLString: serverURLString,
                        presenceProjection: presenceProjection,
                        presenceScope: presenceScope
                    ) { updatedContent in
                        actions.updateNestedContent(blockID, .detailsContent, updatedContent)
                    }
                } else {
                    NativeEditorNestedDocumentPreview(
                        content: bodyContent,
                        pageID: pageID,
                        spaceID: spaceID,
                        serverURLString: serverURLString
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var isOpen: Bool {
        actions == nil ? transientIsOpen : details.isOpen
    }

    private func toggleOpen() {
        if let actions {
            actions.updateDetails(blockID, details.summary, details.previewText, details.isOpen == false)
        } else {
            transientIsOpen.toggle()
        }
    }
}

struct NativeEditorColumnsBlockView: View {
    let blockID: UUID
    let columns: NativeEditorColumnsBlock
    let columnNodes: [ProseMirrorNode]
    let actions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var parentPresenceScope: [NativeEditorRemotePresenceScope] = []
    var presenceBlockIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NativeEditorResponsiveColumnsLayout(weights: columnWeights) {
                ForEach(columnNodes.enumerated(), id: \.offset) { item in
                    NativeEditorColumnContent(
                        blockID: blockID,
                        index: item.offset,
                        content: item.element.content ?? [],
                        actions: actions,
                        pageID: pageID,
                        spaceID: spaceID,
                        serverURLString: serverURLString,
                        presenceProjection: presenceProjection,
                        parentPresenceScope: parentPresenceScope,
                        presenceBlockIndex: presenceBlockIndex
                    )
                }
            }

            if let actions {
                NativeEditorColumnsEditor(blockID: blockID, columns: columns, actions: actions)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Columns")
    }

}

private extension NativeEditorColumnsBlockView {
    var columnWeights: [Double] {
        NativeEditorColumnsLayoutPolicy.weights(
            layout: columns.layout,
            explicitWidths: columns.normalizedColumnWidths,
            count: columnNodes.count
        )
    }
}

struct NativeEditorDiagramBlockView: View {
    @Environment(AppState.self) private var appState
    @State private var authorizedSourceURL: URL?
    @State private var resourceCookies: [StoredHTTPCookie] = []

    let blockID: UUID
    let diagram: NativeEditorDiagramBlock
    let title: String
    let systemImage: String
    let serverURLString: String?
    let update: ((UUID, String, String, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sourceURL {
                Group {
                    if authorizedSourceURL == sourceURL {
                        NativeEditorWebEmbedView(
                            html: NativeEditorWebEmbedHTML.imageHTML(source: sourceURL, title: displayTitle),
                            allowedHosts: Set([sourceURL.host()?.lowercased()].compactMap(\.self)),
                            cookies: resourceCookies
                        )
                    } else {
                        ProgressView("Loading diagram")
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(minHeight: 260)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 1)
                }
                .task(id: sourceURL) {
                    authorizedSourceURL = nil
                    let cookies = await appState.activeSessionCookies(for: sourceURL)
                    guard Task.isCancelled == false else { return }
                    resourceCookies = cookies
                    authorizedSourceURL = sourceURL
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: systemImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.18), in: .rect(cornerRadius: 10))
            }

            if let update {
                NativeEditorDiagramEditor(
                    blockID: blockID,
                    diagram: diagram,
                    update: update
                )
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.12), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .glassEffect(.regular.tint(.white.opacity(0.06)), in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayTitle)
    }

    private var displayTitle: String {
        diagram.title ?? title
    }

    private var subtitle: String? {
        diagram.alternativeText ?? diagram.source
    }

    private var sourceURL: URL? {
        NativeEditorWebURLPolicy.documentResourceURL(
            from: diagram.source,
            serverURLString: serverURLString
        )
    }
}

struct NativeEditorMathBlockView: View {
    let blockID: UUID
    let math: NativeEditorMathBlock
    let actions: NativeEditorRichBlockEditingActions?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 0)
                NativeEditorEquationText(expression: math.text.isEmpty ? "Equation" : math.text)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)

            if let actions {
                NativeEditorMathBlockEditor(blockID: blockID, math: math, actions: actions)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Math equation \(math.text)")
    }
}

private struct NativeEditorEquationText: View {
    let expression: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            ForEach(NativeEditorEquationPiece.pieces(from: expression)) { piece in
                Text(piece.text)
                    .font(piece.kind == .main ? .title3 : .caption)
                    .fontDesign(.serif)
                    .italic()
                    .baselineOffset(piece.kind.baselineOffset)
            }
        }
    }
}

private struct NativeEditorEquationPiece: Identifiable {
    enum Kind {
        case main
        case superscript
        case `subscript`

        var baselineOffset: CGFloat {
            switch self {
            case .main:
                0
            case .superscript:
                8
            case .subscript:
                -4
            }
        }
    }

    let id = UUID()
    let text: String
    let kind: Kind

    static func pieces(from expression: String) -> [NativeEditorEquationPiece] {
        var pieces: [NativeEditorEquationPiece] = []
        var mainText = ""
        var index = expression.startIndex

        while index < expression.endIndex {
            let character = expression[index]
            if character == "^" || character == "_" {
                appendMainText(&mainText, to: &pieces)
                let nextIndex = expression.index(after: index)
                let parsed = parsedScript(in: expression, startingAt: nextIndex)
                if parsed.text.isEmpty == false {
                    pieces.append(NativeEditorEquationPiece(
                        text: parsed.text,
                        kind: character == "^" ? .superscript : .subscript
                    ))
                }
                index = parsed.endIndex
            } else {
                mainText.append(character)
                index = expression.index(after: index)
            }
        }

        appendMainText(&mainText, to: &pieces)
        return pieces.isEmpty ? [NativeEditorEquationPiece(text: expression, kind: .main)] : pieces
    }

    private static func appendMainText(
        _ mainText: inout String,
        to pieces: inout [NativeEditorEquationPiece]
    ) {
        guard mainText.isEmpty == false else { return }
        pieces.append(NativeEditorEquationPiece(text: mainText, kind: .main))
        mainText = ""
    }

    private static func parsedScript(
        in expression: String,
        startingAt index: String.Index
    ) -> (text: String, endIndex: String.Index) {
        guard index < expression.endIndex else {
            return ("", index)
        }

        if expression[index] == "{" {
            let contentStart = expression.index(after: index)
            guard let closeIndex = expression[contentStart...].firstIndex(of: "}") else {
                return ("", contentStart)
            }
            return (String(expression[contentStart..<closeIndex]), expression.index(after: closeIndex))
        }

        return (String(expression[index]), expression.index(after: index))
    }
}

private struct NativeEditorCalloutIcon: View {
    let presentation: NativeEditorCalloutPresentation
    let customIcon: String?

    var body: some View {
        Group {
            if let customIcon, customIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Text(customIcon)
                    .font(.title3)
            } else {
                Image(systemName: presentation.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .font(.title3)
            }
        }
        .foregroundStyle(presentation.tint)
        .frame(width: 24, alignment: .center)
        .accessibilityHidden(true)
    }
}

private struct NativeEditorCalloutPresentation {
    let style: String

    var title: String {
        switch normalizedStyle {
        case "default":
            "Default"
        case "info":
            "Info"
        case "note":
            "Note"
        case "success":
            "Success"
        case "warning":
            "Warning"
        case "danger", "error":
            "Danger"
        default:
            "Info"
        }
    }

    var tint: Color {
        switch normalizedStyle {
        case "default":
            .gray
        case "note":
            .purple
        case "success":
            .green
        case "warning":
            .orange
        case "danger", "error":
            .red
        default:
            .blue
        }
    }

    var systemImage: String {
        switch normalizedStyle {
        case "default":
            "text.bubble"
        case "note":
            "note.text"
        case "success":
            "checkmark.circle.fill"
        case "warning":
            "exclamationmark.triangle.fill"
        case "danger", "error":
            "xmark.octagon.fill"
        default:
            "info.circle.fill"
        }
    }

    private var normalizedStyle: String {
        style.lowercased()
    }
}
