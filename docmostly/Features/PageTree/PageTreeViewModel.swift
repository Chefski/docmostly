import Foundation
import Observation

@MainActor
@Observable
final class PageTreeViewModel {
    var nodes: [PageTreeNode] = []
    var expandedIDs: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    func loadRoot(spaceId: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pages = try await appState.loadSidebarPages(spaceId: spaceId)
            nodes = pages.map(PageTreeNode.init(page:)).sortedByPosition()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(node: PageTreeNode, appState: AppState) async {
        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
            return
        }

        expandedIDs.insert(node.id)

        guard node.hasChildren, node.isChildrenLoaded == false else {
            return
        }

        do {
            let children = try await appState.loadSidebarPages(spaceId: node.spaceId, pageId: node.id)
            let childNodes = children.map(PageTreeNode.init(page:)).sortedByPosition()
            nodes.updateNode(id: node.id) { existing in
                existing.children = childNodes
                existing.isChildrenLoaded = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
