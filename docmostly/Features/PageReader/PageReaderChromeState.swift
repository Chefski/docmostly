import Foundation

enum PageReaderMode: String, CaseIterable, Identifiable {
    case edit
    case read

    var id: Self { self }

    var title: String {
        switch self {
        case .edit:
            "Edit"
        case .read:
            "Read"
        }
    }
}

enum PageReaderPanel: String, Identifiable {
    case comments
    case tableOfContents

    var id: Self { self }

    var title: String {
        switch self {
        case .comments:
            "Comments"
        case .tableOfContents:
            "Table of Contents"
        }
    }
}

enum PageReaderCommentTab: String, CaseIterable, Identifiable {
    case open
    case resolved

    var id: Self { self }

    var title: String {
        switch self {
        case .open:
            "Open"
        case .resolved:
            "Resolved"
        }
    }
}

struct PageReaderTableOfContentsItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let level: Int

    static func items(in document: NativeEditorDocument) -> [Self] {
        document.blocks.compactMap { block in
            guard case .heading(let level) = block.kind, level <= 4 else {
                return nil
            }

            let title = String(block.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard title.isEmpty == false else { return nil }

            return PageReaderTableOfContentsItem(id: block.id, title: title, level: max(level, 1))
        }
    }
}
