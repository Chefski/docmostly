import Foundation

nonisolated struct PageBrowserItem: Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
    let spaceId: String?
    let subtitle: String
    let updatedAt: Date?

    init(page: DocmostPage, fallbackSpaceName: String) {
        id = page.id
        slugId = page.slugId
        title = page.title.isEmpty ? "Untitled" : page.title
        icon = page.icon
        spaceId = page.spaceId
        subtitle = page.space?.name ?? page.space?.slug ?? fallbackSpaceName
        updatedAt = page.updatedAt
    }

    init?(favorite: DocmostFavorite, fallbackSpaceName: String) {
        guard favorite.type == .page, let page = favorite.page else { return nil }

        id = page.id
        slugId = page.slugId
        title = page.title.isEmpty ? "Untitled" : page.title
        icon = page.icon
        spaceId = page.spaceId
        subtitle = fallbackSpaceName
        updatedAt = nil
    }
}
