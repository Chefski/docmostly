import Foundation
import Observation

@MainActor
@Observable
final class PageTreeViewModel {
    private(set) var nodes: [PageTreeNode] = []
    private(set) var visibleNodes: [PageTreeVisibleNode] = []
    private var expandedIDs: Set<String> = []
    var isLoading = false
    var isPerformingAction = false
    var isLoadingTrash = false
    var trashPages: [DocmostPage] = []
    var errorMessage: String?
    var isLoadingSpaceActions = false
    var isFavoriteSpace = false
    var isWatchingSpace: Bool?
    var isTogglingSpaceFavorite = false
    var isTogglingSpaceWatch = false
    var spaceActionErrorMessage: String?

    var isPerformingSpaceAction: Bool {
        isLoadingSpaceActions || isTogglingSpaceFavorite || isTogglingSpaceWatch
    }

    func loadRoot(spaceId: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pages = try await appState.loadSidebarPages(spaceId: spaceId)
            nodes = pages.map(PageTreeNode.init(page:)).sortedByPosition()
            rebuildVisibleNodes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearPages() {
        nodes = []
        expandedIDs = []
        rebuildVisibleNodes()
    }

    func loadSpaceActionState(spaceId: String, appState: AppState) async {
        isLoadingSpaceActions = true
        spaceActionErrorMessage = nil
        defer { isLoadingSpaceActions = false }

        async let favoriteIDsOutcome = captureLoad {
            try await appState.loadFavoriteIds(type: .space)
        }
        async let watchStatusOutcome = captureLoad {
            try await appState.loadSpaceWatchStatus(spaceId: spaceId)
        }

        let favorites = await favoriteIDsOutcome
        let watchStatus = await watchStatusOutcome
        isFavoriteSpace = favorites.value?.contains(spaceId) ?? false
        isWatchingSpace = watchStatus.value?.watching
        spaceActionErrorMessage = favorites.errorMessage ?? watchStatus.errorMessage
    }

    func toggleSpaceFavorite(spaceId: String, appState: AppState) async {
        guard isTogglingSpaceFavorite == false else { return }

        isTogglingSpaceFavorite = true
        spaceActionErrorMessage = nil
        defer { isTogglingSpaceFavorite = false }

        do {
            if isFavoriteSpace {
                try await appState.removeFavorite(type: .space, spaceId: spaceId)
                isFavoriteSpace = false
            } else {
                try await appState.addFavorite(type: .space, spaceId: spaceId)
                isFavoriteSpace = true
            }
        } catch {
            spaceActionErrorMessage = error.localizedDescription
        }
    }

    func toggleSpaceWatch(spaceId: String, appState: AppState) async {
        guard isTogglingSpaceWatch == false else { return }

        isTogglingSpaceWatch = true
        spaceActionErrorMessage = nil
        defer { isTogglingSpaceWatch = false }

        do {
            let response = if isWatchingSpace == true {
                try await appState.unwatchSpace(spaceId: spaceId)
            } else {
                try await appState.watchSpace(spaceId: spaceId)
            }
            isWatchingSpace = response.watching
        } catch {
            spaceActionErrorMessage = error.localizedDescription
        }
    }

    func toggle(node: PageTreeNode, appState: AppState) async {
        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
            rebuildVisibleNodes()
            return
        }

        expandedIDs.insert(node.id)
        rebuildVisibleNodes()

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
            rebuildVisibleNodes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPage(
        title: String,
        parentPageId: String?,
        spaceId: String,
        appState: AppState
    ) async -> DocmostPage? {
        await performAction {
            if let parentPageId {
                try await ensureChildrenLoaded(parentPageId: parentPageId, appState: appState)
                expandedIDs.insert(parentPageId)
                rebuildVisibleNodes()
            }

            let page = try await appState.createPage(
                spaceId: spaceId,
                parentPageId: parentPageId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
            insert(PageTreeNode(page: page), parentPageId: parentPageId)
            appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
            return page
        }
    }

    func duplicatePage(_ node: PageTreeNode, targetSpaceId: String?, appState: AppState) async -> Bool {
        let page: DocmostPage? = await performAction {
            let page = try await appState.duplicatePage(pageId: node.id, spaceId: targetSpaceId)
            if page.spaceId == node.spaceId {
                insert(PageTreeNode(page: page), parentPageId: page.parentPageId)
            }
            appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
            return page
        }
        return page != nil
    }

    func movePageToSpace(_ node: PageTreeNode, targetSpaceId: String, appState: AppState) async -> Bool {
        let moved: Bool? = await performAction {
            try await appState.movePageToSpace(pageId: node.id, spaceId: targetSpaceId)
            nodes = nodes.removing(id: node.id)
            rebuildVisibleNodes()
            appState.selectSpace(id: targetSpaceId, clearsPage: appState.selectedPageID == node.slugId)
            return true
        }
        return moved == true
    }

    func deletePage(_ node: PageTreeNode, appState: AppState) async {
        await performAction {
            try await appState.deletePage(pageId: node.id)
            nodes = nodes.removing(id: node.id)
            rebuildVisibleNodes()
            if appState.selectedPageID == node.slugId {
                appState.clearSelectedPage()
            }
            return ()
        }
    }

    func movePage(sourceID: String, operation: PageTreeDropOperation, appState: AppState) async {
        let previousNodes = nodes

        do {
            let payload = try nodes.movePayload(sourceID: sourceID, operation: operation)
            let movedTree = try nodes.moving(sourceID: sourceID, operation: operation).tree
            nodes = movedTree
            nodes.updateNode(id: sourceID) { node in
                node.parentPageId = payload.parentPageId
                node.position = payload.position
            }
            rebuildVisibleNodes()
            try await appState.movePage(payload)
        } catch {
            nodes = previousNodes
            rebuildVisibleNodes()
            errorMessage = error.localizedDescription
        }
    }

    func loadTrash(spaceId: String, appState: AppState) async {
        isLoadingTrash = true
        errorMessage = nil
        defer { isLoadingTrash = false }

        do {
            trashPages = try await appState.loadDeletedPages(spaceId: spaceId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePage(_ page: DocmostPage, appState: AppState) async {
        await performAction {
            let restored = try await appState.restorePage(pageId: page.id)
            trashPages.removeAll { $0.id == page.id }
            insert(PageTreeNode(page: restored), parentPageId: restored.parentPageId)
            return ()
        }
    }

    func permanentlyDeletePage(_ page: DocmostPage, appState: AppState) async {
        await performAction {
            try await appState.deletePage(pageId: page.id, permanentlyDelete: true)
            trashPages.removeAll { $0.id == page.id }
            return ()
        }
    }

    private func ensureChildrenLoaded(parentPageId: String, appState: AppState) async throws {
        guard let parent = nodes.node(id: parentPageId), parent.isChildrenLoaded == false else { return }
        let children = try await appState.loadSidebarPages(spaceId: parent.spaceId, pageId: parent.id)
        nodes.updateNode(id: parentPageId) { existing in
            existing.children = children.map(PageTreeNode.init(page:)).sortedByPosition()
            existing.isChildrenLoaded = true
            existing.hasChildren = true
        }
        rebuildVisibleNodes()
    }

    private func insert(_ node: PageTreeNode, parentPageId: String?) {
        if parentPageId == nil {
            nodes.append(node)
            nodes = nodes.sortedByPosition()
            rebuildVisibleNodes()
            return
        }

        nodes.updateNode(id: parentPageId ?? "") { parent in
            parent.children.append(node)
            parent.children = parent.children.sortedByPosition()
            parent.hasChildren = true
            parent.isChildrenLoaded = true
        }
        rebuildVisibleNodes()
    }

    private func rebuildVisibleNodes() {
        visibleNodes = nodes.visibleNodes(expandedIDs: expandedIDs)
    }

    private func performAction<Result>(_ action: () async throws -> Result) async -> Result? {
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }

        do {
            return try await action()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func captureLoad<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async -> PageTreeLoadOutcome<Value> {
        do {
            return PageTreeLoadOutcome(value: try await operation(), errorMessage: nil)
        } catch {
            return PageTreeLoadOutcome(value: nil, errorMessage: error.localizedDescription)
        }
    }
}

private struct PageTreeLoadOutcome<Value: Sendable>: Sendable {
    let value: Value?
    let errorMessage: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
