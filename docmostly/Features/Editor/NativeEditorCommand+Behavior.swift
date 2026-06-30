import Foundation

extension NativeEditorCommand {
    var attachmentImportKind: NativeEditorAttachmentImportKind? {
        switch self {
        case .image:
            .image
        case .video:
            .video
        case .audio:
            .audio
        case .pdf:
            .pdf
        case .fileAttachment:
            .file
        default:
            nil
        }
    }

    func matches(query: String) -> Bool {
        matchPriority(query: query) != nil
    }

    func matchPriority(query: String) -> Int? {
        guard query.isEmpty == false else { return 0 }

        if title.localizedStandardContainsAtWordStart(query) {
            return 0
        }

        if searchTerms.contains(where: { $0.localizedStandardContains(query) }) {
            return 1
        }

        if title.fuzzyMatchesSlashCommandQuery(query) {
            return 2
        }

        if rawValue.localizedStandardContains(query) {
            return 3
        }

        if subtitle.localizedStandardContains(query) {
            return 3
        }

        if title.localizedStandardContains(query) {
            return 4
        }

        return nil
    }

    private var searchTerms: [String] {
        switch self {
        case .paragraph:
            ["p", "text", "paragraph"]
        case .heading1:
            ["title", "big", "large", "h1"]
        case .heading2:
            ["subtitle", "medium", "h2"]
        case .heading3:
            ["subtitle", "small", "h3"]
        case .bulletedList:
            ["unordered", "point", "list"]
        case .numberedList:
            ["numbered", "ordered", "list", "ol"]
        case .todoList:
            ["todo", "task", "list", "check", "checkbox"]
        case .quote:
            ["blockquote", "quotes"]
        case .codeBlock:
            ["codeblock", "snippet"]
        case .image:
            ["photo", "picture", "media", "file", "attachment"]
        case .video:
            ["mp4", "media", "file", "attachment"]
        case .audio:
            ["music", "sound", "mp3", "media", "file", "attachment"]
        case .pdf:
            ["document", "embed"]
        case .fileAttachment:
            ["upload", "csv", "zip"]
        case .table:
            ["rows", "columns"]
        case .baseInline:
            ["base", "database", "table", "grid", "spreadsheet"]
        case .kanban:
            ["board", "cards", "status", "task", "database"]
        case .callout:
            ["notice", "panel", "info", "warning", "success", "error", "danger"]
        case .details:
            ["collapsible", "block", "toggle", "details", "expand"]
        case .mathInline:
            ["math", "inline", "mathinline", "inlinemath", "inline math", "equation", "katex", "latex", "tex"]
        case .pageBreak:
            ["page", "break", "pagebreak", "print"]
        case .divider:
            ["horizontal rule", "hr"]
        case .columns:
            ["layout", "split", "side"]
        case .columns3:
            ["layout", "split", "triple"]
        case .columns4, .columns5:
            ["layout", "split"]
        case .subpages:
            ["child", "children", "nested", "hierarchy", "toc"]
        case .syncedBlock:
            ["sync", "excerpt", "transclusion", "reusable", "snippet"]
        case .embed:
            ["url", "external", "iframe"]
        case .iframeEmbed:
            ["iframe"]
        case .airtableEmbed:
            ["airtable"]
        case .loomEmbed:
            ["loom"]
        case .figmaEmbed:
            ["figma"]
        case .typeformEmbed:
            ["typeform"]
        case .miroEmbed:
            ["miro"]
        case .youtubeEmbed:
            ["youtube", "yt", "media", "video"]
        case .vimeoEmbed:
            ["vimeo"]
        case .framerEmbed:
            ["framer"]
        case .googleDriveEmbed:
            ["google drive", "gdrive"]
        case .googleSheetsEmbed:
            ["google sheets", "gsheets"]
        case .mathBlock:
            ["math", "block", "mathblock", "block math", "equation", "katex", "latex", "tex"]
        case .mermaid:
            ["diagrams", "chart", "uml"]
        case .drawio:
            ["diagrams", "charts", "uml", "whiteboard"]
        case .excalidraw:
            ["diagrams", "draw", "sketch", "whiteboard"]
        case .date:
            ["today"]
        case .time:
            ["now", "clock"]
        case .status:
            ["badge", "label", "lozenge"]
        case .emoji:
            ["icon", "smiley", "emoticon", "symbol", "reaction"]
        }
    }
}

private extension String {
    func localizedStandardContainsAtWordStart(_ query: String) -> Bool {
        guard query.isEmpty == false else { return true }

        var searchStart = startIndex
        while searchStart < endIndex {
            let searchText = self[searchStart..<endIndex]
            guard let range = searchText.localizedStandardRange(of: query) else { return false }
            if range.lowerBound == startIndex {
                return true
            }

            let previousIndex = index(before: range.lowerBound)
            let previousCharacter = self[previousIndex]
            if previousCharacter.isWhitespace || previousCharacter.isPunctuation {
                return true
            }
            searchStart = range.upperBound
        }

        return false
    }

    func fuzzyMatchesSlashCommandQuery(_ query: String) -> Bool {
        let normalizedQuery = query.lowercased()
        guard normalizedQuery.isEmpty == false else { return true }

        var queryIndex = normalizedQuery.startIndex
        for character in lowercased() where character == normalizedQuery[queryIndex] {
            queryIndex = normalizedQuery.index(after: queryIndex)
            if queryIndex == normalizedQuery.endIndex {
                return true
            }
        }

        return false
    }
}
