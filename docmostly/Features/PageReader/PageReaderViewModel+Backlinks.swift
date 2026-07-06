import Foundation

extension PageReaderViewModel {
    func loadBacklinks(
        pageID: String,
        direction: DocmostBacklinkDirection,
        appState: AppState,
        reset: Bool = false,
        loadNextPage: Bool = false
    ) async {
        let loadKey = PageReaderBacklinkLoadKey(pageID: pageID, direction: direction)
        guard loadingBacklinkDirections.contains(loadKey) == false else { return }

        if backlinkPageID != pageID || reset {
            backlinkPageID = pageID
            backlinkPagesByDirection = [:]
            backlinkNextCursorByDirection = [:]
            backlinkHasNextPageByDirection = [:]
            backlinkErrorMessage = nil
        }

        if loadNextPage {
            guard backlinkHasNextPageByDirection[direction] == true else { return }
        } else if reset == false, backlinkPagesByDirection[direction]?.isEmpty == false {
            return
        }

        loadingBacklinkDirections.insert(loadKey)
        backlinkErrorMessage = nil
        defer { loadingBacklinkDirections.remove(loadKey) }

        do {
            let cursor = loadNextPage ? backlinkNextCursorByDirection[direction] ?? nil : nil
            let response = try await appState.loadPageBacklinks(pageId: pageID, direction: direction, cursor: cursor)
            guard backlinkPageID == pageID else { return }

            if reset || loadNextPage == false {
                backlinkPagesByDirection[direction] = response.items
            } else {
                let existingPages = backlinkPagesByDirection[direction] ?? []
                backlinkPagesByDirection[direction] = existingPages + response.items
            }
            backlinkNextCursorByDirection[direction] = response.meta.nextCursor
            backlinkHasNextPageByDirection[direction] = response.meta.hasNextPage
        } catch {
            backlinkErrorMessage = error.localizedDescription
        }
    }

    func loadMoreBacklinks(
        pageID: String,
        direction: DocmostBacklinkDirection,
        appState: AppState
    ) async {
        guard backlinkHasNextPageByDirection[direction] == true else { return }
        await loadBacklinks(pageID: pageID, direction: direction, appState: appState, loadNextPage: true)
    }
}
