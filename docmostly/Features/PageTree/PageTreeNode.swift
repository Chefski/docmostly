import Foundation

struct PageTreeNode: Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
    let spaceId: String
    let parentPageId: String?
    let position: String?
    let hasChildren: Bool
    var children: [PageTreeNode]
    var isChildrenLoaded: Bool

    init(page: DocmostPage) {
        id = page.id
        slugId = page.slugId
        title = page.title.isEmpty ? "Untitled" : page.title
        icon = page.icon
        spaceId = page.spaceId
        parentPageId = page.parentPageId
        position = page.position
        hasChildren = page.hasChildren ?? false
        children = []
        isChildrenLoaded = false
    }
}
