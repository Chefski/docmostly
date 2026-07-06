import Foundation

extension PageReaderViewModel {
    func loadBacklinks(
        pageID: String,
        direction: DocmostBacklinkDirection,
        appState: AppState,
        reset: Bool = false
    ) async {
        guard loadingBacklinkDirections.contains(direction) == false else { return }
        if reset == false, backlinkPagesByDirection[direction]?.isEmpty == false {
            return
        }

        loadingBacklinkDirections.insert(direction)
        backlinkErrorMessage = nil
        defer { loadingBacklinkDirections.remove(direction) }

        do {
            let cursor = reset ? nil : backlinkNextCursorByDirection[direction] ?? nil
            let response = try await appState.loadPageBacklinks(pageId: pageID, direction: direction, cursor: cursor)
            if reset {
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
        await loadBacklinks(pageID: pageID, direction: direction, appState: appState)
    }
}
