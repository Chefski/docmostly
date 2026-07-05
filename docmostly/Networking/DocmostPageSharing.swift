import Foundation

nonisolated struct DocmostSharePageSummary: Decodable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
}

nonisolated struct DocmostPageShare: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let key: String
    let pageId: String
    let includeSubPages: Bool
    let searchIndexing: Bool
    let creatorId: String?
    let spaceId: String
    let workspaceId: String?
    let level: Int?
    let sharedPage: DocmostSharePageSummary?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?

    var isDirectShare: Bool {
        (level ?? 0) == 0
    }

    var isInheritedShare: Bool {
        (level ?? 0) > 0
    }
}

nonisolated struct DocmostPageRestrictionInfo: Decodable, Hashable, Sendable {
    let restrictionId: String?
    let hasDirectRestriction: Bool
    let hasInheritedRestriction: Bool
    let inheritedFrom: DocmostSharePageSummary?
    let userAccess: DocmostPageRestrictionAccess

    var hasAnyRestriction: Bool {
        hasDirectRestriction || hasInheritedRestriction
    }
}

nonisolated struct DocmostPageRestrictionAccess: Decodable, Hashable, Sendable {
    let canView: Bool
    let canEdit: Bool
    let canManage: Bool
}

nonisolated enum DocmostPagePermissionRole: String, Decodable, Hashable, Sendable {
    case reader
    case writer
}

nonisolated enum DocmostPagePermissionMemberType: String, Decodable, Hashable, Sendable {
    case user
    case group
}

nonisolated struct DocmostPagePermissionMember: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let type: DocmostPagePermissionMemberType
    let name: String
    let role: DocmostPagePermissionRole
    let email: String?
    let avatarUrl: String?
    let memberCount: Int?
    let isDefault: Bool?
    let createdAt: Date?
}
