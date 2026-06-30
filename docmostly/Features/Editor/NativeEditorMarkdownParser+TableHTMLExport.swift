import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableMarkdown(from table: NativeEditorTable) -> String? {
        guard tableRequiresHTMLMarkdown(table), table.rows.isEmpty == false else { return nil }

        let rows = table.rows.map(htmlTableRowMarkdown).joined(separator: "\n")
        return """
        <div class="tableWrapper">
        <table>
        <tbody>
        \(rows)
        </tbody>
        </table>
        </div>
        """
    }

    private static func tableRequiresHTMLMarkdown(_ table: NativeEditorTable) -> Bool {
        table.rows.contains { row in
            row.cells.contains(where: cellRequiresHTMLMarkdown)
        }
    }

    private static func cellRequiresHTMLMarkdown(_ cell: NativeEditorTableCell) -> Bool {
        if tableCellPreservedContentRequiresHTML(cell) {
            return true
        }

        return cell.backgroundColor != nil ||
            cell.backgroundColorName != nil ||
            cell.columnSpan > 1 ||
            cell.rowSpan > 1 ||
            cell.columnWidths.isEmpty == false
    }

    private static func tableCellPreservedContentRequiresHTML(_ cell: NativeEditorTableCell) -> Bool {
        guard let preservedContent = cell.preservedContent, preservedContent.isEmpty == false else {
            return false
        }

        let hasUnsupportedInlineContent = cell.inlineContent?.contains(where: isUnsupportedInlineContent) ?? false
        guard preservedContent.count == 1,
              let paragraph = preservedContent.first,
              paragraph.type == "paragraph",
              hasUnsupportedInlineContent == false else {
            return true
        }

        let attrs = paragraph.attrs ?? [:]
        return attrs.keys.allSatisfy { $0 == "textAlign" } == false
    }

    private static func isUnsupportedInlineContent(_ item: NativeEditorInlineContent) -> Bool {
        if case .unsupported = item {
            return true
        }

        return false
    }

    private static func htmlTableRowMarkdown(from row: NativeEditorTableRow) -> String {
        let cells = row.cells.map(htmlTableCellMarkdown).joined(separator: "\n")
        return """
        <tr>
        \(cells)
        </tr>
        """
    }

    private static func htmlTableCellMarkdown(from cell: NativeEditorTableCell) -> String {
        let tagName = cell.isHeader ? "th" : "td"
        let attrs = htmlTableCellAttributes(from: cell)
        return "<\(tagName)\(attrs)>\(htmlTableCellBodyMarkdown(from: cell))</\(tagName)>"
    }

    private static func htmlTableCellAttributes(from cell: NativeEditorTableCell) -> String {
        var attrs: [(String, String?)] = []
        attrs.append(("data-background-color", cell.backgroundColor))
        attrs.append(("data-background-color-name", cell.backgroundColorName))
        if cell.columnSpan > 1 {
            attrs.append(("colspan", "\(cell.columnSpan)"))
        }
        if cell.rowSpan > 1 {
            attrs.append(("rowspan", "\(cell.rowSpan)"))
        }
        if cell.columnWidths.isEmpty == false {
            attrs.append(("colwidth", cell.columnWidths.map(String.init).joined(separator: ",")))
        }

        let attributeText = attrs.compactMap { name, value in
            value?.nonEmpty.map { #"\#(name)="\#(escapedInlineHTMLAttribute($0))""# }
        }
        .joined(separator: " ")

        return attributeText.isEmpty ? "" : " \(attributeText)"
    }

    private static func htmlTableCellBodyMarkdown(from cell: NativeEditorTableCell) -> String {
        if let preservedContent = cell.preservedContent, preservedContent.isEmpty == false {
            return preservedContent.map(htmlTableCellContentMarkdown).joined()
        }

        if let inlineContent = cell.inlineContent {
            return "<p>\(htmlTableInlineMarkdown(from: inlineContent))</p>"
        }

        return "<p>\(escapedInlineHTMLText(cell.plainText))</p>"
    }

    private static func htmlTableCellContentMarkdown(from node: ProseMirrorNode) -> String {
        if let textContent = htmlTableTextContentMarkdown(from: node) {
            return textContent
        }
        if let listContent = htmlTableListContentMarkdown(from: node) {
            return listContent
        }
        if let containerContent = htmlTableContainerContentMarkdown(from: node) {
            return containerContent
        }
        if let structuralContent = htmlTableStructuralContentMarkdown(from: node) {
            return structuralContent
        }
        if let mediaContent = htmlTableMediaContentMarkdown(from: node) {
            return mediaContent
        }

        return htmlTableUnsupportedNodeMarkdown(from: node)
    }

    private static func htmlTableTextContentMarkdown(from node: ProseMirrorNode) -> String? {
        switch node.type {
        case "paragraph":
            "<p\(htmlTableTextAlignAttribute(from: node))>\(htmlTableInlineMarkdown(from: node.content ?? []))</p>"
        case "heading":
            htmlTableHeadingMarkdown(from: node)
        case "codeBlock":
            htmlTableCodeBlockMarkdown(from: node)
        case "horizontalRule":
            "<hr>"
        default:
            nil
        }
    }

    private static func htmlTableListContentMarkdown(from node: ProseMirrorNode) -> String? {
        switch node.type {
        case "bulletList":
            htmlTableListMarkdown(from: node, tagName: "ul", attrs: [])
        case "orderedList":
            htmlTableListMarkdown(from: node, tagName: "ol", attrs: htmlTableOrderedListAttrs(from: node))
        case "taskList":
            htmlTableListMarkdown(from: node, tagName: "ul", attrs: [("data-type", "taskList")])
        case "listItem":
            htmlTableListItemMarkdown(from: node, attrs: [])
        case "taskItem":
            htmlTableListItemMarkdown(from: node, attrs: htmlTableTaskItemAttrs(from: node))
        default:
            nil
        }
    }

    private static func htmlTableContainerContentMarkdown(from node: ProseMirrorNode) -> String? {
        switch node.type {
        case "callout":
            htmlTableCalloutMarkdown(from: node)
        case "blockquote":
            htmlTableBlockquoteMarkdown(from: node)
        case "details":
            htmlTableDetailsMarkdown(from: node)
        case "columns":
            htmlTableColumnsMarkdown(from: node)
        case "column":
            htmlTableColumnMarkdown(from: node)
        default:
            nil
        }
    }

    private static func htmlTableStructuralContentMarkdown(from node: ProseMirrorNode) -> String? {
        switch node.type {
        case "mathBlock":
            htmlTableMathBlockMarkdown(from: node)
        case "base":
            htmlTableBaseMarkdown(from: node)
        case "transclusionReference":
            htmlTableTransclusionReferenceMarkdown(from: node)
        case "transclusionSource":
            htmlTableTransclusionSourceMarkdown(from: node)
        case "subpages":
            #"<div data-type="subpages"></div>"#
        case "pageBreak":
            #"<div data-type="pageBreak" class="page-break"></div>"#
        default:
            nil
        }
    }

    private static func htmlTableMediaContentMarkdown(from node: ProseMirrorNode) -> String? {
        switch node.type {
        case "image":
            htmlTableImageMarkdown(from: node)
        case "video", "audio":
            htmlTableMediaElementMarkdown(from: node)
        case "pdf":
            htmlTablePDFMarkdown(from: node)
        case "attachment":
            htmlTableAttachmentMarkdown(from: node)
        case "embed":
            htmlTableEmbedMarkdown(from: node)
        case "drawio", "excalidraw":
            htmlTableDiagramMarkdown(from: node)
        default:
            nil
        }
    }

    private static func htmlTableHeadingMarkdown(from node: ProseMirrorNode) -> String {
        let level = min(max(node.attrs?["level"]?.intValue ?? 1, 1), 6)
        let attributes = htmlTableTextAlignAttribute(from: node)
        let body = htmlTableInlineMarkdown(from: node.content ?? [])
        return "<h\(level)\(attributes)>\(body)</h\(level)>"
    }

    private static func htmlTableCodeBlockMarkdown(from node: ProseMirrorNode) -> String {
        let language = node.attrs?["language"]?.stringValue?.nonEmpty
            .map { #" class="language-\#(escapedInlineHTMLAttribute($0))""# } ?? ""
        return "<pre><code\(language)>\(escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node])))</code></pre>"
    }

    private static func htmlTableListMarkdown(
        from node: ProseMirrorNode,
        tagName: String,
        attrs: [(String, String?)]
    ) -> String {
        let openingTag = htmlTableTag(tagName, attrs: attrs)
        let items = (node.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        return """
        \(openingTag)
        \(items)
        </\(tagName)>
        """
    }

    private static func htmlTableOrderedListAttrs(from node: ProseMirrorNode) -> [(String, String?)] {
        guard let start = node.attrs?["start"]?.intValue, start != 1 else { return [] }
        return [("start", "\(start)")]
    }

    private static func htmlTableTaskItemAttrs(from node: ProseMirrorNode) -> [(String, String?)] {
        [("data-type", "taskItem"), ("data-checked", node.attrs?["checked"]?.boolValue == true ? "true" : nil)]
    }

    private static func htmlTableListItemMarkdown(
        from node: ProseMirrorNode,
        attrs: [(String, String?)]
    ) -> String {
        let body = (node.content ?? []).map(htmlTableCellContentMarkdown).joined()
        return "\(htmlTableTag("li", attrs: attrs))\(body)</li>"
    }

    private static func htmlTableCalloutMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "callout"),
            ("data-callout-type", htmlTableAttr("type", from: node) ?? "info"),
            ("data-callout-icon", htmlTableAttr("icon", from: node))
        ])
        let body = (node.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        return """
        \(openingTag)
        \(body)
        </div>
        """
    }

    private static func htmlTableBlockquoteMarkdown(from node: ProseMirrorNode) -> String {
        let body = (node.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        return """
        <blockquote>
        \(body)
        </blockquote>
        """
    }

    private static func htmlTableDetailsMarkdown(from node: ProseMirrorNode) -> String {
        let summary = node.content?.first(where: { $0.type == "detailsSummary" })
        let detailsContent = node.content?.first(where: { $0.type == "detailsContent" })
        let summaryText = summary
            .map { htmlTableInlineMarkdown(from: $0.content ?? []) }
            .flatMap(\.nonEmpty) ?? "Details"
        let body = (detailsContent?.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        let openingTag = htmlTableTag("details", attrs: [
            ("open", node.attrs?["open"]?.boolValue == true ? "" : nil)
        ])

        return """
        \(openingTag)
        <summary data-type="detailsSummary">\(summaryText)</summary>
        <div data-type="detailsContent">
        \(body)
        </div>
        </details>
        """
    }

    private static func htmlTableColumnsMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "columns"),
            ("data-layout", htmlTableAttr("layout", from: node)),
            ("data-width-mode", htmlTableAttr("widthMode", from: node))
        ])
        let columns = (node.content ?? []).map(htmlTableColumnMarkdown).joined(separator: "\n")
        return """
        \(openingTag)
        \(columns)
        </div>
        """
    }

    private static func htmlTableColumnMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "column"),
            ("data-width", htmlTableAttr("width", from: node))
        ])
        let body = (node.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        return """
        \(openingTag)
        \(body)
        </div>
        """
    }

    private static func htmlTableMathBlockMarkdown(from node: ProseMirrorNode) -> String {
        let text = htmlTableAttr("text", from: node) ?? NativeEditorDocument.plainText(in: [node])
        return #"<div data-type="mathBlock" data-katex="true">\#(escapedInlineHTMLText(text))</div>"#
    }

    private static func htmlTableBaseMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "base-embed"),
            ("data-page-id", htmlTableAttr("pageId", from: node))
        ])
        return "\(openingTag)</div>"
    }

    private static func htmlTableTransclusionReferenceMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "transclusionReference"),
            ("data-source-page-id", htmlTableAttr("sourcePageId", from: node)),
            ("data-transclusion-id", htmlTableAttr("transclusionId", from: node))
        ])
        return "\(openingTag)</div>"
    }

    private static func htmlTableTransclusionSourceMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "transclusionSource"),
            ("data-id", htmlTableAttr("id", from: node))
        ])
        let body = (node.content ?? []).map(htmlTableCellContentMarkdown).joined(separator: "\n")
        return """
        \(openingTag)
        \(body)
        </div>
        """
    }

    private static func htmlTableImageMarkdown(from node: ProseMirrorNode) -> String {
        htmlTableTag("img", attrs: htmlTableMediaAttrs(from: node, includesTitle: true))
    }

    private static func htmlTableMediaElementMarkdown(from node: ProseMirrorNode) -> String {
        let isVideo = node.type == "video"
        let openingTag = htmlTableTag(node.type, attrs: [
            ("controls", "true"),
            ("src", htmlTableAttr("src", from: node)),
            ("aria-label", isVideo ? htmlTableAttr("alt", from: node) : nil),
            ("data-attachment-id", htmlTableAttr("attachmentId", from: node)),
            ("width", htmlTableAttr("width", from: node)),
            ("height", htmlTableAttr("height", from: node)),
            ("data-size", htmlTableAttr("size", from: node)),
            ("data-align", htmlTableAttr("align", from: node)),
            ("data-aspect-ratio", isVideo ? htmlTableAttr("aspectRatio", from: node) : nil),
            ("preload", isVideo ? nil : "metadata")
        ])
        let sourceTag = htmlTableTag("source", attrs: [("src", htmlTableAttr("src", from: node))])
        return """
        \(openingTag)
        \(sourceTag)
        </\(node.type)>
        """
    }

    private static func htmlTablePDFMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "pdf"),
            ("src", htmlTableAttr("src", from: node)),
            ("data-name", htmlTableAttr("name", from: node)),
            ("data-attachment-id", htmlTableAttr("attachmentId", from: node)),
            ("data-size", htmlTableAttr("size", from: node)),
            ("width", htmlTableAttr("width", from: node)),
            ("height", htmlTableAttr("height", from: node))
        ])
        let iframeTag = htmlTableTag("iframe", attrs: [
            ("src", htmlTableAttr("src", from: node)),
            ("width", htmlTableAttr("width", from: node)),
            ("height", htmlTableAttr("height", from: node))
        ])
        return """
        \(openingTag)
        \(iframeTag)</iframe>
        </div>
        """
    }

    private static func htmlTableAttachmentMarkdown(from node: ProseMirrorNode) -> String {
        let source = htmlTableAttr("url", from: node)
        let name = htmlTableAttr("name", from: node)
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "attachment"),
            ("data-attachment-url", source),
            ("data-attachment-name", name),
            ("data-attachment-mime", htmlTableAttr("mime", from: node)),
            ("data-attachment-size", htmlTableAttr("size", from: node)),
            ("data-attachment-id", htmlTableAttr("attachmentId", from: node))
        ])
        let linkTag = htmlTableTag("a", attrs: [
            ("href", source),
            ("class", "attachment"),
            ("target", "blank")
        ])
        let title = escapedInlineHTMLText(name ?? source ?? "Attachment")
        return """
        \(openingTag)
        \(linkTag)\(title)</a>
        </div>
        """
    }

    private static func htmlTableEmbedMarkdown(from node: ProseMirrorNode) -> String {
        let source = htmlTableAttr("src", from: node)
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", "embed"),
            ("data-src", source),
            ("data-provider", htmlTableAttr("provider", from: node)),
            ("data-align", htmlTableAttr("align", from: node)),
            ("data-width", htmlTableAttr("width", from: node)),
            ("data-height", htmlTableAttr("height", from: node))
        ])
        let linkTag = htmlTableTag("a", attrs: [
            ("href", source),
            ("target", "blank")
        ])
        return """
        \(openingTag)
        \(linkTag)\(escapedInlineHTMLText(source ?? "Embed"))</a>
        </div>
        """
    }

    private static func htmlTableDiagramMarkdown(from node: ProseMirrorNode) -> String {
        let openingTag = htmlTableTag("div", attrs: [
            ("data-type", node.type),
            ("data-src", htmlTableAttr("src", from: node)),
            ("data-title", htmlTableAttr("title", from: node)),
            ("data-alt", htmlTableAttr("alt", from: node)),
            ("data-width", htmlTableAttr("width", from: node)),
            ("data-height", htmlTableAttr("height", from: node)),
            ("data-size", htmlTableAttr("size", from: node)),
            ("data-aspect-ratio", htmlTableAttr("aspectRatio", from: node)),
            ("data-align", htmlTableAttr("align", from: node)),
            ("data-attachment-id", htmlTableAttr("attachmentId", from: node))
        ])
        let imageTag = htmlTableTag("img", attrs: [
            ("src", htmlTableAttr("src", from: node)),
            ("alt", htmlTableAttr("alt", from: node) ?? htmlTableAttr("title", from: node)),
            ("width", htmlTableAttr("width", from: node))
        ])
        return """
        \(openingTag)
        \(imageTag)
        </div>
        """
    }

    private static func htmlTableMediaAttrs(
        from node: ProseMirrorNode,
        includesTitle: Bool
    ) -> [(String, String?)] {
        [
            ("src", htmlTableAttr("src", from: node)),
            ("alt", htmlTableAttr("alt", from: node)),
            ("title", includesTitle ? htmlTableAttr("title", from: node) : nil),
            ("width", htmlTableAttr("width", from: node)),
            ("height", htmlTableAttr("height", from: node)),
            ("data-align", htmlTableAttr("align", from: node)),
            ("data-attachment-id", htmlTableAttr("attachmentId", from: node)),
            ("data-size", htmlTableAttr("size", from: node)),
            ("data-aspect-ratio", htmlTableAttr("aspectRatio", from: node))
        ]
    }

    private static func htmlTableUnsupportedNodeMarkdown(from node: ProseMirrorNode) -> String {
        let attrs = node.attrs?.compactMap { key, value -> String? in
            guard let text = value.htmlAttributeValue else { return nil }
            return #"data-\#(key)="\#(escapedInlineHTMLAttribute(text))""#
        }
        .sorted()
        .joined(separator: " ") ?? ""
        let attrText = attrs.isEmpty ? "" : " \(attrs)"
        let body = node.content?.map(htmlTableCellContentMarkdown).joined() ??
            escapedInlineHTMLText(node.text ?? NativeEditorDocument.plainText(in: [node]))
        return #"<div data-type="\#(escapedInlineHTMLAttribute(node.type))"\#(attrText)>\#(body)</div>"#
    }

    private static func htmlTableTextAlignAttribute(from node: ProseMirrorNode) -> String {
        guard let alignment = node.attrs?["textAlign"]?.stringValue?.nonEmpty else { return "" }
        return #" style="text-align: \#(escapedInlineHTMLAttribute(alignment))""#
    }

    private static func htmlTableInlineMarkdown(from inlineContent: [NativeEditorInlineContent]) -> String {
        inlineContent
            .map(NativeEditorDocument.attributedText(from:))
            .map(inlineMarkdown(from:))
            .joined()
    }

    private static func htmlTableInlineMarkdown(from nodes: [ProseMirrorNode]) -> String {
        nodes.map(htmlTableInlineMarkdown(from:)).joined()
    }

    private static func htmlTableInlineMarkdown(from node: ProseMirrorNode) -> String {
        switch node.type {
        case "text":
            htmlTableMarkedInlineMarkdown(from: node)
        case "hardBreak":
            "<br>"
        case "mention", "status", "mathInline":
            inlineMarkdown(
                from: NativeEditorDocument.attributedText(from: NativeEditorDocument.inlineContent(from: node))
            )
        default:
            escapedInlineHTMLText(node.text ?? NativeEditorDocument.plainText(in: [node]))
        }
    }

    static func htmlTableTag(_ name: String, attrs: [(String, String?)]) -> String {
        let attrText = attrs.compactMap { key, value -> String? in
            guard let value else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }
        .joined(separator: " ")

        return attrText.isEmpty ? "<\(name)>" : "<\(name) \(attrText)>"
    }

    private static func htmlTableAttr(_ name: String, from node: ProseMirrorNode) -> String? {
        node.attrs?[name]?.htmlAttributeValue?.nonEmpty
    }
}

private extension ProseMirrorJSONValue {
    var htmlAttributeValue: String? {
        switch self {
        case .string(let value):
            value
        case .int(let value):
            "\(value)"
        case .double(let value):
            String(value)
        case .bool(let value):
            value ? "true" : "false"
        case .null:
            nil
        case .object, .array:
            nil
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
