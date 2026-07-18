import Foundation

extension AppState {
    func selectSidebarDestination(_ destination: SidebarDestination?) {
        selectedSidebarDestination = destination

        if case .space(let spaceID) = destination {
            selectSpace(id: spaceID)
        }
    }

    func selectSidebarUtilityDestination(_ destination: SidebarDestination) {
        if case .space(let spaceID) = destination {
            selectSpace(id: spaceID)
            return
        }

        selectedSidebarDestination = destination
        selectedPageID = nil
        selectedCommentID = nil
    }

    func selectSpace(id spaceID: String, clearsPage: Bool = true) {
        selectedSpaceID = spaceID
        selectedSidebarDestination = .space(spaceID)

        if clearsPage {
            selectedPageID = nil
            selectedCommentID = nil
        }
    }

    func selectPage(
        id pageID: String,
        spaceID: String? = nil,
        revealSpaceInSidebar: Bool = false,
        commentID: String? = nil
    ) {
        if let spaceID {
            selectedSpaceID = spaceID

            if revealSpaceInSidebar {
                selectedSidebarDestination = .space(spaceID)
            }
        }

        selectedPageID = pageID
        selectedCommentID = commentID
    }

    func openPage(_ target: PageOpenTarget) {
        selectPage(
            id: target.slugId,
            spaceID: target.spaceId,
            revealSpaceInSidebar: target.revealSpaceInSidebar,
            commentID: target.commentId
        )
    }

    func clearSelectedPage() {
        selectedPageID = nil
        selectedCommentID = nil
    }

    func clearSelectedPage(ifMatching pageID: String) {
        guard selectedPageID == pageID else { return }
        clearSelectedPage()
    }

    func resetNavigationSelection() {
        selectedSidebarDestination = nil
        selectedSpaceID = nil
        selectedPageID = nil
        selectedCommentID = nil
    }

    func selectDefaultSpaceIfNeeded() {
        if let selectedSpaceID, spaces.contains(where: { $0.id == selectedSpaceID }) {
            if selectedSidebarDestination == nil {
                selectedSidebarDestination = .space(selectedSpaceID)
            }
            return
        }

        let shouldRevealDefaultSpace = switch selectedSidebarDestination {
        case nil, .space:
            true
        case .favorites, .notifications, .search, .settings:
            false
        }

        selectedSpaceID = nil
        selectedPageID = nil
        selectedCommentID = nil

        guard let firstSpaceID = spaces.first?.id else {
            if shouldRevealDefaultSpace {
                selectedSidebarDestination = nil
            }
            return
        }

        selectedSpaceID = firstSpaceID

        if shouldRevealDefaultSpace {
            selectedSidebarDestination = .space(firstSpaceID)
        }
    }
}
