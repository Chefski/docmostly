import Foundation

nonisolated enum OfflineMutationKind: String, Codable, CaseIterable, Sendable {
    case updatePage
    case createComment
    case resolveComment
    case addPageLabels
    case removePageLabel
    case addFavorite
    case removeFavorite
    case watchPage
    case unwatchPage
    case watchSpace
    case unwatchSpace
    case movePage
    case movePageToSpace
}

nonisolated enum OfflineMutationPayload: Codable, Equatable, Sendable {
    case updatePage(pageId: String, title: String, document: ProseMirrorDocument)
    case createComment(
        pageId: String,
        content: String,
        type: DocmostCommentType,
        selection: String?,
        yjsSelection: NativeEditorYjsSelection?
    )
    case resolveComment(commentId: String, pageId: String, resolved: Bool)
    case addPageLabels(pageId: String, names: [String])
    case removePageLabel(pageId: String, labelId: String)
    case addFavorite(type: FavoriteType, pageId: String?, spaceId: String?, templateId: String?)
    case removeFavorite(type: FavoriteType, pageId: String?, spaceId: String?, templateId: String?)
    case watchPage(pageId: String)
    case unwatchPage(pageId: String)
    case watchSpace(spaceId: String)
    case unwatchSpace(spaceId: String)
    case movePage(pageId: String, parentPageId: String?, position: String)
    case movePageToSpace(pageId: String, spaceId: String)

    var kind: OfflineMutationKind {
        switch self {
        case .updatePage:
            .updatePage
        case .createComment:
            .createComment
        case .resolveComment:
            .resolveComment
        case .addPageLabels:
            .addPageLabels
        case .removePageLabel:
            .removePageLabel
        case .addFavorite:
            .addFavorite
        case .removeFavorite:
            .removeFavorite
        case .watchPage:
            .watchPage
        case .unwatchPage:
            .unwatchPage
        case .watchSpace:
            .watchSpace
        case .unwatchSpace:
            .unwatchSpace
        case .movePage:
            .movePage
        case .movePageToSpace:
            .movePageToSpace
        }
    }

    var coalescingKey: String? {
        switch self {
        case .updatePage(let pageId, _, _):
            "\(kind.rawValue):\(pageId)"
        case .resolveComment(let commentId, _, _):
            "\(kind.rawValue):\(commentId)"
        case .addFavorite(let type, let pageId, let spaceId, let templateId),
                .removeFavorite(let type, let pageId, let spaceId, let templateId):
            "favorite:\(type.rawValue):\(pageId ?? ""):\(spaceId ?? ""):\(templateId ?? "")"
        case .watchPage(let pageId), .unwatchPage(let pageId):
            "pageWatch:\(pageId)"
        case .watchSpace(let spaceId), .unwatchSpace(let spaceId):
            "spaceWatch:\(spaceId)"
        case .movePage(let pageId, _, _), .movePageToSpace(let pageId, _):
            "pageMove:\(pageId)"
        case .createComment, .addPageLabels, .removePageLabel:
            nil
        }
    }
}

nonisolated struct OfflineMutationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let scope: CacheScope
    let kind: OfflineMutationKind
    let payload: OfflineMutationPayload
    let createdAt: Date
    let updatedAt: Date
    let replayOrder: Int
    let attemptCount: Int
    let lastErrorMessage: String?
}
