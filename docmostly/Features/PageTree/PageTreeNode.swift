import Foundation

struct PageTreeNode: Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    var title: String
    let icon: String?
    let spaceId: String
    var parentPageId: String?
    var position: String?
    var hasChildren: Bool
    var children: [PageTreeNode]
    var isChildrenLoaded: Bool

    init(
        id: String,
        slugId: String,
        title: String,
        icon: String?,
        spaceId: String,
        parentPageId: String?,
        position: String?,
        hasChildren: Bool,
        children: [PageTreeNode] = [],
        isChildrenLoaded: Bool = false
    ) {
        self.id = id
        self.slugId = slugId
        self.title = title.isEmpty ? "Untitled" : title
        self.icon = icon
        self.spaceId = spaceId
        self.parentPageId = parentPageId
        self.position = position
        self.hasChildren = hasChildren
        self.children = children
        self.isChildrenLoaded = isChildrenLoaded
    }

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
