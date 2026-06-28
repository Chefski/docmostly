import Foundation

nonisolated enum OfflineMutationPayload: Codable, Equatable, Sendable {
    case updatePage(pageId: String, title: String, document: ProseMirrorDocument)
    case createComment(
        localId: String,
        pageId: String,
        content: String,
        plainText: String,
        type: DocmostCommentType,
        selection: String?,
        yjsSelection: NativeEditorYjsSelection?
    )
    case resolveComment(commentId: String, pageId: String, resolved: Bool)
    case addPageLabels(pageId: String, labels: [OfflinePageLabel])
    case removePageLabel(pageId: String, labelId: String)
    case addFavorite(type: FavoriteType, pageId: String?, spaceId: String?, templateId: String?)
    case removeFavorite(type: FavoriteType, pageId: String?, spaceId: String?, templateId: String?)
    case watchPage(pageId: String)
    case unwatchPage(pageId: String)
    case watchSpace(spaceId: String)
    case unwatchSpace(spaceId: String)
    case movePage(pageId: String, parentPageId: String?, position: String)
    case movePageToSpace(pageId: String, spaceId: String)

    private enum CodingKeys: String, CodingKey {
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

    private enum PayloadCodingKeys: String, CodingKey {
        case pageId
        case title
        case document
        case localId
        case content
        case plainText
        case type
        case selection
        case yjsSelection
        case commentId
        case resolved
        case labels
        case names
        case labelId
        case spaceId
        case templateId
        case parentPageId
        case position
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.updatePage) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .updatePage)
            self = try .updatePage(
                pageId: payload.decode(String.self, forKey: .pageId),
                title: payload.decode(String.self, forKey: .title),
                document: payload.decode(ProseMirrorDocument.self, forKey: .document)
            )
        } else if container.contains(.createComment) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .createComment)
            let pageId = try payload.decode(String.self, forKey: .pageId)
            let content = try payload.decode(String.self, forKey: .content)
            let type = try payload.decode(DocmostCommentType.self, forKey: .type)
            let selection = try payload.decodeIfPresent(String.self, forKey: .selection)
            self = try .createComment(
                localId: payload.decodeIfPresent(String.self, forKey: .localId)
                    ?? Self.legacyCommentID(pageId: pageId, content: content, type: type, selection: selection),
                pageId: pageId,
                content: content,
                plainText: payload.decodeIfPresent(String.self, forKey: .plainText) ?? content,
                type: type,
                selection: selection,
                yjsSelection: payload.decodeIfPresent(NativeEditorYjsSelection.self, forKey: .yjsSelection)
            )
        } else if container.contains(.resolveComment) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .resolveComment)
            self = try .resolveComment(
                commentId: payload.decode(String.self, forKey: .commentId),
                pageId: payload.decode(String.self, forKey: .pageId),
                resolved: payload.decode(Bool.self, forKey: .resolved)
            )
        } else if container.contains(.addPageLabels) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .addPageLabels)
            let pageId = try payload.decode(String.self, forKey: .pageId)
            let labels = try payload.decodeIfPresent([OfflinePageLabel].self, forKey: .labels)
                ?? payload.decode([String].self, forKey: .names).map { OfflinePageLabel(pageId: pageId, name: $0) }
            self = .addPageLabels(pageId: pageId, labels: labels)
        } else if container.contains(.removePageLabel) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .removePageLabel)
            self = try .removePageLabel(
                pageId: payload.decode(String.self, forKey: .pageId),
                labelId: payload.decode(String.self, forKey: .labelId)
            )
        } else if container.contains(.addFavorite) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .addFavorite)
            self = try .addFavorite(
                type: payload.decode(FavoriteType.self, forKey: .type),
                pageId: payload.decodeIfPresent(String.self, forKey: .pageId),
                spaceId: payload.decodeIfPresent(String.self, forKey: .spaceId),
                templateId: payload.decodeIfPresent(String.self, forKey: .templateId)
            )
        } else if container.contains(.removeFavorite) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .removeFavorite)
            self = try .removeFavorite(
                type: payload.decode(FavoriteType.self, forKey: .type),
                pageId: payload.decodeIfPresent(String.self, forKey: .pageId),
                spaceId: payload.decodeIfPresent(String.self, forKey: .spaceId),
                templateId: payload.decodeIfPresent(String.self, forKey: .templateId)
            )
        } else if container.contains(.watchPage) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .watchPage)
            self = try .watchPage(pageId: payload.decode(String.self, forKey: .pageId))
        } else if container.contains(.unwatchPage) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .unwatchPage)
            self = try .unwatchPage(pageId: payload.decode(String.self, forKey: .pageId))
        } else if container.contains(.watchSpace) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .watchSpace)
            self = try .watchSpace(spaceId: payload.decode(String.self, forKey: .spaceId))
        } else if container.contains(.unwatchSpace) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .unwatchSpace)
            self = try .unwatchSpace(spaceId: payload.decode(String.self, forKey: .spaceId))
        } else if container.contains(.movePage) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .movePage)
            self = try .movePage(
                pageId: payload.decode(String.self, forKey: .pageId),
                parentPageId: payload.decodeIfPresent(String.self, forKey: .parentPageId),
                position: payload.decode(String.self, forKey: .position)
            )
        } else if container.contains(.movePageToSpace) {
            let payload = try container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .movePageToSpace)
            self = try .movePageToSpace(
                pageId: payload.decode(String.self, forKey: .pageId),
                spaceId: payload.decode(String.self, forKey: .spaceId)
            )
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .updatePage,
                in: container,
                debugDescription: "Queued offline mutation payload has no supported operation."
            )
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .updatePage(let pageId, let title, let document):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .updatePage)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(title, forKey: .title)
            try payload.encode(document, forKey: .document)
        case .createComment(
            let localId,
            let pageId,
            let content,
            let plainText,
            let type,
            let selection,
            let yjsSelection
        ):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .createComment)
            try payload.encode(localId, forKey: .localId)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(content, forKey: .content)
            try payload.encode(plainText, forKey: .plainText)
            try payload.encode(type, forKey: .type)
            try payload.encodeIfPresent(selection, forKey: .selection)
            try payload.encodeIfPresent(yjsSelection, forKey: .yjsSelection)
        case .resolveComment(let commentId, let pageId, let resolved):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .resolveComment)
            try payload.encode(commentId, forKey: .commentId)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(resolved, forKey: .resolved)
        case .addPageLabels(let pageId, let labels):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .addPageLabels)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(labels, forKey: .labels)
        case .removePageLabel(let pageId, let labelId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .removePageLabel)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(labelId, forKey: .labelId)
        case .addFavorite(let type, let pageId, let spaceId, let templateId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .addFavorite)
            try payload.encode(type, forKey: .type)
            try payload.encodeIfPresent(pageId, forKey: .pageId)
            try payload.encodeIfPresent(spaceId, forKey: .spaceId)
            try payload.encodeIfPresent(templateId, forKey: .templateId)
        case .removeFavorite(let type, let pageId, let spaceId, let templateId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .removeFavorite)
            try payload.encode(type, forKey: .type)
            try payload.encodeIfPresent(pageId, forKey: .pageId)
            try payload.encodeIfPresent(spaceId, forKey: .spaceId)
            try payload.encodeIfPresent(templateId, forKey: .templateId)
        case .watchPage(let pageId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .watchPage)
            try payload.encode(pageId, forKey: .pageId)
        case .unwatchPage(let pageId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .unwatchPage)
            try payload.encode(pageId, forKey: .pageId)
        case .watchSpace(let spaceId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .watchSpace)
            try payload.encode(spaceId, forKey: .spaceId)
        case .unwatchSpace(let spaceId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .unwatchSpace)
            try payload.encode(spaceId, forKey: .spaceId)
        case .movePage(let pageId, let parentPageId, let position):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .movePage)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encodeIfPresent(parentPageId, forKey: .parentPageId)
            try payload.encode(position, forKey: .position)
        case .movePageToSpace(let pageId, let spaceId):
            var payload = container.nestedContainer(keyedBy: PayloadCodingKeys.self, forKey: .movePageToSpace)
            try payload.encode(pageId, forKey: .pageId)
            try payload.encode(spaceId, forKey: .spaceId)
        }
    }

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

    func replacingCommentIDs(_ mappings: [String: String]) -> OfflineMutationPayload {
        guard mappings.isEmpty == false else { return self }

        switch self {
        case .updatePage(let pageId, let title, let document):
            var patchedDocument = document
            var didReplace = false
            for mapping in mappings {
                let replacement = patchedDocument.replacingCommentID(mapping.key, with: mapping.value)
                patchedDocument = replacement.document
                didReplace = didReplace || replacement.didReplace
            }
            guard didReplace else { return self }
            return .updatePage(pageId: pageId, title: title, document: patchedDocument)
        default:
            return self
        }
    }

    private static func legacyCommentID(
        pageId: String,
        content: String,
        type: DocmostCommentType,
        selection: String?
    ) -> String {
        let rawID = "\(pageId)|\(type.rawValue)|\(content)|\(selection ?? "")"
        return "offline-comment-legacy-\(stableHexDigest(of: rawID))"
    }

    private static func stableHexDigest(of value: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
