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

nonisolated struct PageReaderCollaborationPresenceTaskKey: Equatable, Sendable {
    let pageID: String
    let participation: NativeEditorCollaborationParticipation
}

nonisolated enum PageReaderCollaborationTaskKeys {
    static func collaborationPresence(
        pageID: String,
        participation: NativeEditorCollaborationParticipation
    ) -> PageReaderCollaborationPresenceTaskKey {
        PageReaderCollaborationPresenceTaskKey(pageID: pageID, participation: participation)
    }

    static func collaborationPresence(
        pageID: String?,
        participation: NativeEditorCollaborationParticipation,
        isVisible: Bool = true
    ) -> PageReaderCollaborationPresenceTaskKey? {
        guard let pageID, isVisible else { return nil }
        return PageReaderCollaborationPresenceTaskKey(pageID: pageID, participation: participation)
    }

    static func realtimeEvents(
        pageID: String,
        participation: NativeEditorCollaborationParticipation
    ) -> String {
        pageID
    }

    static func realtimeEvents(
        pageID: String?,
        participation: NativeEditorCollaborationParticipation
    ) -> String? {
        pageID
    }

    static func crdtDocumentSnapshots(
        pageID: String,
        participation: NativeEditorCollaborationParticipation
    ) -> String {
        pageID
    }

    static func crdtDocumentSnapshots(
        pageID: String?,
        participation: NativeEditorCollaborationParticipation
    ) -> String? {
        pageID
    }
}

enum PageReaderPanel: String, Identifiable {
    case details
    case comments
    case tableOfContents
    case attachments
    case sharing

    var id: Self { self }

    var title: String {
        switch self {
        case .details:
            "Details"
        case .comments:
            "Comments"
        case .tableOfContents:
            "Table of Contents"
        case .attachments:
            "Attachments"
        case .sharing:
            "Sharing"
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
