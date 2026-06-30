import Foundation

nonisolated struct DocmostMentionSuggestionResponse: Decodable, Sendable {
    var users: [DocmostMentionUserSuggestion]
    var pages: [DocmostMentionPageSuggestion]

    var isEmpty: Bool {
        users.isEmpty && pages.isEmpty
    }

    init(
        users: [DocmostMentionUserSuggestion] = [],
        pages: [DocmostMentionPageSuggestion] = []
    ) {
        self.users = users
        self.pages = pages
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        users = try container.decodeIfPresent([DocmostMentionUserSuggestion].self, forKey: .users) ?? []
        pages = try container.decodeIfPresent([DocmostMentionPageSuggestion].self, forKey: .pages) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case users
        case pages
    }
}

nonisolated struct DocmostMentionUserSuggestion: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String?
    let avatarUrl: String?
}

nonisolated struct DocmostMentionPageSuggestion: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
    let spaceId: String?
    let isBase: Bool?
    let space: DocmostMentionSpaceSuggestion?

    init(
        id: String,
        slugId: String,
        title: String,
        icon: String?,
        spaceId: String?,
        isBase: Bool? = nil,
        space: DocmostMentionSpaceSuggestion?
    ) {
        self.id = id
        self.slugId = slugId
        self.title = title
        self.icon = icon
        self.spaceId = spaceId
        self.isBase = isBase
        self.space = space
    }

    init(searchResult: DocmostSearchResult) {
        self.init(
            id: searchResult.id,
            slugId: searchResult.slugId,
            title: searchResult.title,
            icon: searchResult.icon,
            spaceId: searchResult.space.id,
            space: DocmostMentionSpaceSuggestion(
                id: searchResult.space.id,
                name: searchResult.space.name,
                slug: searchResult.space.slug,
                icon: searchResult.space.icon
            )
        )
    }
}

nonisolated struct DocmostMentionSpaceSuggestion: Decodable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let icon: String?
}
