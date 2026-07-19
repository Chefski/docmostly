import Foundation

nonisolated struct DocmostTransclusionReference: Codable, Equatable, Hashable, Sendable {
    let sourcePageId: String
    let transclusionId: String
}

nonisolated struct DocmostTransclusionLookupRequest: Encodable, Equatable, Sendable {
    static let maximumReferences = 50

    let references: [DocmostTransclusionReference]
}

nonisolated struct DocmostTransclusionLookupResponse: Decodable, Equatable, Sendable {
    let items: [DocmostTransclusionLookupItem]
}

nonisolated enum DocmostTransclusionLookupStatus: String, Decodable, Equatable, Sendable {
    case notFound = "not_found"
    case noAccess = "no_access"
}

nonisolated enum DocmostTransclusionLookupItem: Decodable, Equatable, Sendable {
    case resolved(
        reference: DocmostTransclusionReference,
        content: ProseMirrorDocument,
        sourceUpdatedAt: Date
    )
    case notFound(reference: DocmostTransclusionReference)
    case noAccess(reference: DocmostTransclusionReference)

    var reference: DocmostTransclusionReference {
        switch self {
        case .resolved(let reference, _, _), .notFound(let reference), .noAccess(let reference):
            reference
        }
    }

    var content: ProseMirrorDocument? {
        guard case .resolved(_, let content, _) = self else { return nil }
        return content
    }

    var sourceUpdatedAt: Date? {
        guard case .resolved(_, _, let sourceUpdatedAt) = self else { return nil }
        return sourceUpdatedAt
    }

    var status: DocmostTransclusionLookupStatus? {
        switch self {
        case .resolved:
            nil
        case .notFound:
            .notFound
        case .noAccess:
            .noAccess
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sourcePageId
        case transclusionId
        case content
        case sourceUpdatedAt
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reference = DocmostTransclusionReference(
            sourcePageId: try container.decode(String.self, forKey: .sourcePageId),
            transclusionId: try container.decode(String.self, forKey: .transclusionId)
        )

        switch try container.decodeIfPresent(DocmostTransclusionLookupStatus.self, forKey: .status) {
        case .notFound:
            self = .notFound(reference: reference)
        case .noAccess:
            self = .noAccess(reference: reference)
        case nil:
            let content = try container.decode(ProseMirrorDocument.self, forKey: .content)
            try content.validateNativeEditorBudget()
            self = .resolved(
                reference: reference,
                content: content,
                sourceUpdatedAt: try container.decode(Date.self, forKey: .sourceUpdatedAt)
            )
        }
    }
}
